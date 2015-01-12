---
layout: blogpost
title: What's up with monomorphism?
date: 2015-01-11
---

Talks and blog posts about JavaScript performance often emphasize importance of *monomorphic* code. However they usually don't provide any digestible explanation of what monomorphism/polymorhism is and why it matters. Even in my own talks it often boils down to Hulk-style &laquo;**ONE TYPE GOOD. TWO TYPE BAD!!!**&raquo; dichotomy. Unsurprisingly one of the most common requests I get when people reach out to me for a performance advice is a request to explain _what monomorphism actually means_, how polymorphism arises and why it is bad. I have answered this question in so many different ways that I finally decided to write a blog post about it - so that next time I can just link to it and not improvise.

<small>[I also decided to try a new approach to explaining things - trying to capture interactions between various parts of the virtual machine in short comics. This is an new area for me, so please don't hesitate and send any feedback my way. Does it make it easier to understand? Does it make it harder to understand?]</small>

Dynamic lookup 101
------------------

<img src="/images/2015-01-11/v8-vs-ox.png" style="float: left;">

For simplicity this post will mostly concentrate on the simplest property access in JavaScript, like `o.x` in the code below. At the same time it's important to understand that everything we are going to talk about applies to any _dynamically bound_ operation be it a property lookup or an arithmetic and even goes beyond JavaScript.

{% highlight javascript %}
function f(o) {
  return o.x
}

f({ x: 1 })
f({ x: 2 })
{% endhighlight %}

Imagine for a moment that you are interviewing for a great position at Interpreters Ltd. and your interviewer asks you to design and implement property lookup for a JavaScript VM. What would be the simplest and most straightforward answer to this question?

Obviously you can't go any simpler than taking JS semantics as it is described in the ECMAScript Language Specification (aka ECMA 262) and transcribing [\[\[Get\]\]](http://es5.github.io/#x8.12.3) algorithm word by word from English into C++, Java, Rust or Malbolge depending on your language of choice for the interview.

In fact if you open a random JS interpreter you are most likely to discover something like this:

{% highlight cpp %}
jsvalue Get(jsvalue self, jsvalue property_name) {
  // 8.12.3 [[Get]] implementation goes here
}

void Interpret(jsbytecodes bc) {
  // ...
  while (/* has more bytecodes */) {
    switch (op) {
      // ...
      case OP_GETPROP: {
        jsvalue property_name = pop();
        jsvalue receiver = pop();
        push(Get(receiver, property_name));
        // TODO(mraleph): throw exception in strict mode per 8.7.1 step 3.
        break;
      }
      // ...
    }
  }
}
{% endhighlight %}

This is an absolutely valid way to implement property lookup, however it has one significant problem: if we pit our property lookup implementation against those used in modern JS VMs we will discover that it is far too slow.

Our interpreter is _amnesiac_: every time it does a property lookup it has to execute a generic property lookup algorithm from scratch, it does not learn anything from the previous attempts and has to pay full price again and again. That's why performance oriented VMs implement property lookup in a different way.

<img src="/images/2015-01-11/ic.png" style="float: left;">

What if it did? What if each property access in our program was capable of learning from objects that it saw before and apply this knowledge to similar objects? Potentially that would allow us to save a lot of time by avoiding costly generic lookup algorithm and instead use a quicker one that only applies to objects of certain _shape_.

We know that it is costly to figure out where the given property is inside an arbitrary object, so we would like to do this lookup once and then put the _path_ to this property into a cache using _object's shape_ as a key. Next time we see an object with the same shape we can just get the path from the cache instead of computing it from scratch.

This optimization technique is known as **Inline Caching** and I have [written about it before](http://mrale.ph/blog/2012/06/03/explaining-js-vms-in-js-inline-caches.html). For this post I am going to leave concrete implementation details aside and will instead focus on an aspect I previously ignored: each inline cache is first and foremost **a cache** and just like any other cache it has _size_ (number of currently cached entries) and _capacity_ (maximum number of cached entries).

Lets take a look at the example again:

{% highlight javascript %}
function f(o) {
  return o.x
}

f({ x: 1 })
f({ x: 2 })
{% endhighlight %}

What's the expected number of cached entries for IC at `o.x`?

<p class="sidenote-host"><small class="sidenote">mono- ("one") + -morphic ("of a form")</small>Given that <code>{x: 1}</code> and <code>{x: 2}</code> have the same shape the answer is 1. This is precisely the state of cache that we call <em>monomorphic</em> because it saw only objects of a single shape.</p>

<img src="/images/2015-01-11/ic-poly.png" style="float: right;">

What happens if we now call `f` with an object of a different shape?

{% highlight javascript %}
f({ x: 3 })
// o.x cache is still monomorphic here
f({ x: 3, y: 1 })
// what about now?
{% endhighlight %}

`{x: 3}` and `{x: 3, y: 1}` are objects of different shapes so the cache is no longer monomorphic, it now contains two cache entries one for a shape `{x: *}` and one for a shape `{x: *, y: *}` - our operation now is in  _polymorphic_ state with a degree of polymorphism `2`.

If we continue calling `f` with objects of different hidden classes it's degree of polymorphism will continue to grow until it reaches a predefined threshold - maximum possible capacity for the inline cache (e.g. `4` for property loads in V8) - at that point cache will transition to a _megamorphic_ state.

{% highlight javascript %}
f({ x: 4, y: 1 }) // polymorphic, degree 2
f({ x: 5, z: 1 }) // polymorphic, degree 3
f({ x: 6, a: 1 }) // polymorphic, degree 4
f({ x: 7, b: 1 }) // megamorphic
{% endhighlight %}

<img src="/images/2015-01-11/ic-mega.png" style="float: left;">

Megamorphic state exists to prevent uncontrolled growth of polymorphic caches, it means _"I have seen too many shapes **here**, I give up tracking them"_. In V8 megamorphic ICs can still continue to cache things but instead of doing it locally they will put what they want to cache into a global hashtable. This hashtable has a fixed size and entries are simply overwritten on collisions.

<br style="clear:both;">

### Performance implications

At this point performance characteristics of different IC states should become clear:

* monomorphic is the fastest possible IC state if you hit the cache all the time (**ONE TYPE GOOD**);
* ICs in polymorphic state perform linear search among cached entries;
* ICs in megamorphic state probe global hash table and thus are slowest among ICs, but hitting global cache is still better than complete IC miss;
* IC miss is expensive - you have to pay for transitioning to runtime plus cost of the generic operation.

However this is only half of the truth: in addition to speeding up your code inline caches also serve as _spies_ for almighty optimizing compiler --- which will eventually come and try to speed your code even further.

## Speculations and optimizations

Inline caches can't deliver peak performance alone due to two issues:

* each IC acts on it's own, knowing nothing about it's neighbors;
* each IC can ultimately fallback to runtime if it can't handle its input: which means that each IC is essentially a generic operation with generic side-effects and unknown result type.

{% highlight javascript %}
function g(o) {
  return o.x * o.x + o.y * o.y
}

g({x: 0, y: 0})
{% endhighlight %}

For example in the function above each of ICs (`.x`, `.x`, `*`, `.y`, `.y`, `*`, `+`) will act on its own. Each property load IC will check `o` against the same cached shape. Arithmetic IC at `+` will check whether its inputs are numbers (and what kind of number - as V8 internally has different number representations) - even though this could be derived from that state of `*` ICs.

<p class="sidenote-host"><small class="sidenote">[asm.js uses this inherent typing to define an extremely restricted subset of JavaScript that is completely statically typed and can be optimized ahead-of-time, removing the need for speculative adaptive compilation]</small> Arithmetic operations in JavaScript are inherently typed e.g. <code>a|0</code> always returns 32-bit integer and <code>+a</code> always returns a number, but most other operations have no such guarantees. This turns writing an ahead-of-time optimizing compiler for JavaScript into an extremely difficult problem. Instead of compiling JavaScript once in an AOT fashion, most JavaScript VMs sport several execution tiers. For example in V8 code starts to execute without any optimizations, compiled with a baseline non-optimizing compiler. After the code warmed up - hot functions are optimized by an optimizing compiler.</p>

Waiting for code to warm up serves two distinct purposes:

* it decreases startup latency: optimizing compiler is slower than non-optimizing, which means optimized code should be used enough for optimizations to pay off;
* it gives inline caches a chance to collect _type feedback_.

As it was already stressed above human written JavaScript usually does not contain enough inherent type information to allow full static typing and AOT compilation. JIT has to speculate: that is make _educated_ guesses about the usage and behavior of the code it optimizes and generate specialized code that is valid under certain assumptions. Compiler needs to guess what kind of objects are seen in a particular place in the function it optimizes. That's precisely the information inline caches collect!

* Monomorphic cache says "I've **only** seen type A";
* Polymorphic cache of degree N says "I've **only** seen A<sub>1</sub>, ..., A<sub>N</sub>";
* Megamorphic cache says "I've seen a lot of things.";

<img src="/images/2015-01-11/opt-0.png" style="float: left;">

Optimizing compiler looks at the information collected by the caches and assembles _intermediate representation_ (IR) accordingly. IR instructions more specific and low level than normal JS operations. For example if IC for `.x` saw only objects of shape `{x, y}` then optimizer can take an IR instruction that loads property from a fixed offset inside an object and use it to load `.x`. Of course this instruction can't be applied to arbitrary objects (it's unsafe) so optimizer has to prepend a _type guard_ before an unsafe instruction.
