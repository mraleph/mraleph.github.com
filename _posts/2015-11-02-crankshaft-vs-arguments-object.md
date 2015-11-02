---
layout: blogpost
title: Crankshaft vs arguments object
date: 2015-11-02
---

This is a note in reply to [Victor Felder](https://twitter.com/_vhf)'s question
who asked me what *"Unsupported phi use of arguments"* Crankshaft bailout means.

What Crankshaft is trying to do is to _completely avoid allocating `arguments` object_ when you write the code like this:

{% highlight javascript %}
function foo() {
  var sum = 0;
  for (var i = 0; i < arguments.length /* (1) */; i++) {
    sum += arguments[i]; /* (2) */
  }
}
{% endhighlight %}

If one compiles this code naively then an argument object will be allocated when function is entered and a normal property lookup will be used at property access sites `(1)`/`(2)` to find number of arguments and their values respectively. However allocating `arguments` object taxes garbage collector - which might be expensive if this function is very hot - and furthermore is completely unnecessary - as long as optimizing compiler knows that `arguments` contains the `arguments` object in `(1)` and `(2)` it can just emit very short chunks of code to get the length and argument by index right from the _stack_ - because this information is already there and thus there is no need to rewrap it into an `arguments` object.

So essentially the code compiles into something like this:

{% highlight javascript %}
function foo() {
  var sum = 0;
  for (var i = 0;
       i < /* get argument count from the current stack frame */;
       i++) {
    sum += /* get i-th argument from the current stack frame */
  }
}
{% endhighlight %}

Now we just need to make sure to apply this optimization only if we can *easily* establish that it is applicable. *Easily* is a keyword here. Crankshaft often preferred simple solution that cover most useful cases - to more generic but also more complicated solutions.

For example, compiler can obviously easily establish that variable `a` in the code below always contains the current `arguments` object and nothing else.

{% highlight javascript %}
function foo() {
  var sum = 0;
  var a = arguments;
  for (var i = 0; i < a.length; i++) {
    sum += a[i];
  }
}
{% endhighlight %}

Which means optimization described above is still applicable.

There is a very important thing to understand here, so I will reiterate on it: once optimizing compiler chews on this code there will be *no* `arguments` object, it will be dematerialized, it will not exist and neither will variable `a` which contains it. However if a _deoptimization_ happens (e.g. `foo` was always called with numbers and got optimized for number addition, but later somebody called it with a string) then deoptimizer has to reconstruct unoptimized execution environment - and it has to "create" a slot for the variable `a` then materialize `arguments` object and put it into the variable `a`.

Now lets look at a slightly different chunk of code:

{% highlight javascript %}
function foo() {
  var sum = 0;
  var a = arguments;
  if (someCondition) {
      a = [];
  }
  for (var i = 0; i < a.length; i++) {
    sum += a[i];
  }
}
{% endhighlight %}

When compiler sees this it becomes confused: we can no longer statically know what `a` contains - it can contain either `arguments` object or an array. These two objects are completely different internally - because of that we can no longer _easily_ dematerialize `a`. So optimizing compiler just says _"ok, it's too difficult, I give up"_. It gives up because it only supports optimizing functions when arguments object is dematerialized.

This case is exactly the case when *"Unsupported phi use of arguments"* bailout happens.

The confusing "phi" thing mentioned by the message is a phi-function from the SSA-form. Easiest way to explain them is to say that code like this

{% highlight javascript %}
if (x) {
 y = 42;
} else {
 y = 24;
}
use(y);
{% endhighlight %}

is internally represented like this:

{% highlight javascript %}
if (x) {
B0:
 y0 = 42;
} else {
B1:
 y1 = 24;
}
// phi(B0: a, B1: b) is equal to a if control came from B0 and
// is equal to b is control came from B1
y2 = phi(B0: y0, B1: y1);
use(y2);
{% endhighlight %}

This is SSA-form: each variable has exactly on definition (assigned only once) and if variable's value is control dependent (like `y`'s) - then this dependency is captured by a phi function which is placed at control flow merge point and _magically_ knows where control came from.

Returning back to our bailout message: if arguments object flows into a phi it means that there is a variable which either contains arguments object or something else depending on the control flow.

### Does it have to be this way?

As always with optimizing compiler the answer is a superposition of *no* and *yes*.

If I were implementing Crankshaft and `arguments` object specific optimizations today I would probably opt for a completely different approach - off-load most of the `arguments` object optimization into a more generic _load-store forwarding_ and _allocation sinking_ passes. However even that would not be entirely pretty due to abnormal nature of `arguments` object.

A combination of rather straightforward optimization passes could at least handle the code like (which is what I am told some to-JavaScript compilers produce and which is not optimized at all by todays V8):

{% highlight javascript %}
function fac() {
  var a = arguments;
  while (a[0] <= a[1]) {
    a = [a[0] + 1, a[1], a[2] * a[0]];
  }
  return a[2];
}
fac(1, 10, 1);
{% endhighlight %}

Optimizer could turn it into:

{% highlight javascript %}
function fac(a0, a1, a2) {
  // First iteration of the loop is peeled to avoid mixing argument object
  // with array in the same variable (there is another way to handle this: have
  // an artificial value capturing type of object to materialize).
  // Load forwarding and allocation sinking can easily handle the rest.
  if (a0 <= a1) {
    a2 = a2 * a0;
    a0 = a0 + 1;
    while (a0 <= a1) {
      a2 = a2 * a0;
      a0 = a0 + 1;
    }
  }
  return a2;
}
fac(1, 10, 1);
{% endhighlight %}

While I believe that an optimization like this is within reach for most JS VMs I still think that if your to-JavaScript compiler emits the first version of the code and not the second then maybe it's time to implement a real optimization pass *in* your compiler - instead of waiting for JS VMs to do it (especially given that JS VMs are likely to shift focus towards optimizing rest parameters and spread operator - given their more reasonable nature).

Even when we look closely at the code like this:

{% highlight javascript %}
function foo() {
  var sum = 0;
  var a = arguments;
  if (someCondition) {
      a = [1, 2, 3];
  }
  for (var i = 0; i < a.length; i++) {
    sum += a[i];
  }
}
{% endhighlight %}

We discover that it is not inherently unoptimizable. This code uses two objects which are different but are not _that_ different. Optimizing compiler could transform this into something like this:

{% highlight javascript %}
function foo() {
  var sum = 0;
  var a$ptr = /* currentFrame.getArgPointer() */;
  var a$len = /* currentFrame.getArgCount() */;
  var a$typ = "arguments-object";
  if (someCondition) {,
    a$ptr = /* currentFrame.allocateStackSlots(3) */;
    a$len = 3;
    a$ptr[0] = 1;
    a$ptr[1] = 2;
    a$ptr[2] = 3;
    a$typ = "array";
  }
  // If deoptimization happens then deoptimizer can use a$typ to determine
  // what kind of object to rematerialize.
  for (var i = 0; i < a$len; i++) {
    sum += a$ptr[i];
  }
}
{% endhighlight %}

However this optimization is considerably more complicated (as in "it doesn't fit into a simple allocation sinking pass") because it involves stack allocation of an array literal. My prediction would be that a generic optimization of this sort is unlikely to come to JS engines soon. In other words: try to avoid writing or generating code like that.

<small>[I can't resist noting that `arguments` object not being an `Array` is yet another JavaScript wart that causes nothing but special cases and complexity in optimization pipelines all over the world - makes JavaScript harder to optimize and thus makes harder to write optimizable JavaScript]</small>

### Aliasing between `arguments` object and parameters

Another common bailout is caused by aliasing between parameters and `arguments` object.

{% highlight javascript %}
function foo(x) {
  x = 10;
  return arguments[0];
}

print(foo(1));  // => 10
{% endhighlight %}

Crankshaft does not like this aliasing because it influences how SSA-form has to be constructed and refuses to optimize this function. It will happily optimize a strict version of this though as there is no aliasing:

{% highlight javascript %}
function foo(x) {
  "use strict";
  x = 10;
  return arguments[0];
}

print(foo(1));  // => 1
{% endhighlight %}

### Optimizable uses of arguments in V8 (Crankshaft)

Here is a quick check list for optimizable uses of `arguments` object:

* never mix `arguments` object with anything in the same variable;
* property *loads* (not stores!) `a[i]` and `a.length` are optimizable if variable `a` always contains `arguments`;
* `foo.apply(x, a)` are optimizable if variable `a` always contains `arguments`, `foo` is a function, this call site is monomorphic and `apply` is `Function.prototype.apply`.
