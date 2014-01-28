---
layout: blogpost
title: Why asm.js bothers me
date: 2013-03-28
---

**Please note that this post expresses my personal opinion and mine alone, not those of my employer or my teammates.**

I am writing it because I can't hold my opinion inside anymore. My head was starting to feel like a balloon that is going to burst any minute. I am writing my thoughts and feelings down to free myself from this pressure.

When reading my ramblings below please keep in mind that I used to work on V8 and seeing JavaScript in general and V8 in particular getting faster and faster is still one of the things that makes my blood boil with excitement.

What is asm.js?
---------------

If you are not following JavaScript news closely [asm.js](http://asmjs.org) presents itself (quoting its own site) as *"an extraordinarily optimizable, low-level subset of JavaScript"*.

Subset unfortunately is a very opaque word. I am not planning to describe asm.js in details, but I am going to give a very short overview of important aspects. All details are available in the [specification](http://asmjs.org/spec/latest/).

It is well known that generating highly efficient native code from a high level dynamic language like JavaScript is a hard problem. Inefficiencies are usually addressed by piling clever tricks on top of clever tricks to deal with dynamism, late binding and semantical quirks. There is another approach however: *you fix the language itself* to make clever tricks obsolete and potentially enable other clever tricks.

That's exactly what asm.js does. It fixes the language by saying: *fancy features are hard, let us stick to arithmetic*. In practice right now asm.js essentially limits you to:

* arithmetic operations;
* loads and stores into `ArrayBufferView`, all views sharing a single `ArrayBuffer`;
* calls to functions that take numbers as arguments and return number as the result, possible function targets are limited so you can't, for example, create a closure and pass it somewhere.

Additionally asm.js attaches static typing rules to various permitted syntactical constructs. Only code that is consistently typed is considered to be valid. Typing rules are straightforward but not completely trivial, because they for example capture distinction between real 32-bit integers (`signed`) and things that can be coerced to them (`intish`). This somewhat peculiar distinction follows from JavaScript semantics.

For example `(x|0 + y|0)|0` would be typed as `signed`. This is perfectly aligned with the actual JavaScript semantics that essentially interprets this expression as `ToInt32(ToInt32(x) + ToInt32(y))`. If you ever programmed in an assembly or another not-so-high-level language then you'll notice that it exactly matches semantics of overflowing 32-bit integer addition.  I'll return to this expression later, so keep it mind.

The last part of asm.js is the notion of module. All asm.js must be packed into a function that looks like this:

{% highlight javascript %}
function M(stdlib, foreign, heap) {
    "use asm";
    // Section for imports and module variables
    var i32 = new stdlib.Int32Array(heap);
    var f64 = new stdlib.Float64Array(heap);

    var imul = stdlib.Math.imul;
    var truncate = foreign.truncate;

    function foo() {
      var a = 0;  // a is signed
      var b = 0.0; // b is double
      a = i32[0]|0;
      b = +f64[0];
      return imul(a, truncate(b))|0;
    }

    // Export section.
    return { foo: foo };
}


var module = M(window, {
  // Truncate double to integer JS style.
  // x | 0 does not validate as asm.js code, so you can't use it inline.
  // at the same time ~~x would validate as an asm.js code. I misread the
  // spec while writing code and thus decided to use FFI instead of ~~.
  // In any case the fact that ~~x validates while x|0 does not is very
  // confusing.
  truncate: function (x) {
    return x | 0;
  }
}, new ArrayBuffer(4 * 1024));
{% endhighlight %}

There are some important things to notice here:

* `"use asm"` hint tells VM to attempt to validate function `M` as an asm.js module and possibly compile it through *a separate compilation pipeline* if validation succeeds;
* `heap` a single `ArrayBuffer` that is going to be a data storage for all the code inside the module as asm.js rules do not allow any allocation besides creating a number of `ArrayBufferView` objects upon module entry.
* `foreign` is an object that contains *external* functions that you can call from inside your module, you have to explicitly "import" them into local variables upon module entry.
* asm.js is *very* strict, if you remove a single `+` or `|` the code above will be rejected by the validator;
* asm.js puts the compiler's interest before human's e.g. you have to initialize `a` with `0` to tell the validator/compiler that `a` is a variable of type int. In practice this is *already* a no-op for any serious compiler;
* asm.js tries very hard to look just JavaScript but sometimes it fails. `imul` is the best example here. In JavaScript with its single number type there was no way to write overflowing 32bit integer multiplication as something atomically small that is easy to recognize. 32bit addition is simple because the sum of two 32bit integers is at most a 33bit integer and can be represented without loss in a double precision floating point number (which can represent 53bit integers precisely). The product of two 32bit integers however can overflow this precision range. You can shim 32bit multiplication but if you use this shim directly you'll need to complicate your specialized asm.js compiler with fragile pattern matching that recognizes this shim and emits a single assembly instruction. Solution? Push for standardization of `Math.imul` function that performs overflowing 32bit integer multiplication.

What is OdinMonkey?
-------------------

You probably heard about IonMonkey: SpiderMonkey's optimization pipeline for generic JavaScript code similar to V8's Crankshaft.

Modern JavaScript engine are multi-tiered: they have a way to start executing things quickly (using a baseline code generator or interpreter) and a way to produce highly specialized optimized code with an optimizing compiler. Optimized code is usually valid only under certain assumptions that must be verified either internally at the points where optimized code itself relies on them or externally when the runtime system tracks invariants that different optimized code objects rely on and ensures that dependent code objects are discarded when these invariants become invalid.

OdinMonkey is a different beast. It's a module built on top of IonMonkey that takes asm.js code (detected by `"use asm"` annotation), verifies that it is consistently typed and compiles it *ahead of time* into optimized native code.

This ahead-of-time-static-typing is exactly what makes OdinMonkey different from a normal JS engine and closer to say a C++ compiler.

OdinMonkey makes JavaScript fast with insane optimizations!
-----------------------------------------------------------

also known as *It would be great to use asm.js to speed jQuery up!*

Nope. OdinMonkey does not even speak JavaScript. It speaks a statically typed language that by chance looks like JavaScript.

It can't allocate normal JavaScript objects or access normal JavaScript properties. No JavaScript strings. Only arithmetic and typed arrays (a single one actually with multiple views). It can't call arbitrary JavaScript functions, only those that you imported explicitly into your code, and it can only pass numbers into them and get a number out.

Essentially OdinMonkey is a hammer that targets performance sweet spot that is narrower than anything we had before in JavaScript. It hits the spot perfectly but here is the catch, the first danger that I sense: *OdinMonkey is a hammer that will kill incentive to optimize JavaScript that humans write*.

Why waste time optimizing normal, dynamic, fluid like water JavaScript if you can just ask people that they write something more structured and easier for compiler to recognize? Compiler is feeling lazy today, please help it by adding `+` and `|` and don't use normal JS objects or strings, only numbers and a single typed array, to help GC.

I believe that once you take a step on this path it is very hard to abandon it. You will go further and further away from the full language itself, yet you will continue to add things to the host language that your subset desires for performance reasons (see `Math.imul` above).

Which brings me to two questions that bother me and inflate my head.

But why are we taking this step now?
------------------------------------

This is the first one. Honestly I don't know the answer and I am not going to guess.

Somebody might say that we hit performance ceiling with JavaScript and no clever tricks will help us to make it faster than it already is, unless we give up on features and start considering only very assembly like subset.

But I don't believe that normal JavaScript is *anywhere near the end of it's performance path*. On the contrary I believe that JavaScript code of kinds from hand-written jQuery to a Emscripten-generated can be sped up even more!

When I sit down and think about performance gains that asm.js-implementation OdinMonkey-style brings to the table I don't see anything that would not be possible to achieve within a normal JIT compilation framework and thus  simultaneously make human written and compiler generated output faster.

When I take the code above and look at it, as a V8 engineer would look, I can clearly see ways to generate C++ quality native code without actually relying on AOT or static typing.

<p><small>[to be completely honest: there is a certainly a tricky bit with moving out-of-bounds access handling to protection violation handler and not-so-tricky one with actually having `imul` in ES standard to allow efficient number multiplication but neither really require AOT]</small></p>

This might sound weird and hyperbolic, but for me pattern matching a statically typed subset inside JavaScript before exhausting all other possibilities is equal to giving up my pride as a compiler engineer.

Imagine in 2008 V8 would come out and say that it interprets all JavaScript with the same speed all other engines do but it is also exceptionally fast when you `"use hungarian";` and consistently prefix your variable names with their "class":

{% highlight javascript %}
(function () {
  "use hungarian";

  function Point(dX, dY) {
    this.dX = dX;  // dX means field of type double field
    this.dY = dY;
  }

  var apointPoints = []; /* apoint means array of Point type */
  for (var iI = 0; iI < 10; iI = (iI+1)|0) {
    apointPoints[iI] = new Point(iI, iI);
  }

  // and so on.
}
});
{% endhighlight %}

Even as thought experiment it looks ridiculous doesn't it? But that is approximately how I see asm.js. It's a capitulation before JavaScript dynamism, but it is hyped as a victory.

Why is asm.js a JavaScript subset?
----------------------------------

This is the second question that bothers me. It is pretty obvious that asm.js is not really a JavaScript. It is essentially a *bytecode* that looks like JavaScript. This distinction is further highlighted by the fact that SpiderMonkey team is planning to implement *a separate parser for asm.js* instead of using the generic JS parser because the generic parser needs too much memory when you have to AOT compile a huge multi-megabyte asm.js module.

Another thing that makes me thinking is the addition of things like `Math.imul` to the language, it is essentially like adding a bytecode instruction.

Why then we are building this infrastructure on top of the JavaScript language?

Let's be honest and make it explicit: if you want to ship performance critical cross-platform code across the wire define a set of bytecode instructions. You don't need anything fancy: arithmetic, access to typed heap, calls to named functions (API), calls to local functions, etc.

It has multiple advantages:

* evolution of this bytecode format is not tied to the evolution of the JavaScript language;
* semantics of this bytecode does not have to forever tied to JavaScript semantics;
* it keeps JavaScript sweet spot from shrinking;
* vendors are free to implement a separate VM or integrate this bytecode format into underlying VM that executes other language (e.g. JavaScript).

Somebody might say that *it does not run everywhere*. Nope. It does run everywhere: just take JavaScript and write a simple one pass translator from this bytecode to JavaScript. Here you go: it now runs everywhere like JavaScript and it runs faster in browsers that speak this bytecode format. If you are concerned by translation time you can store JavaScript code generated by translation in local storage/IndexedDB.

Layers of polyfills will start piling up in any case as soon as asm.js will proceed to add more "bytecodes" targeted for more efficient execution: e.g. `int64` and `BinaryData` objects. All these features will not be available in older browsers anyway.

Another example of a bytecode like functionality that the host language itself has not use for is [FunctionFuture](https://bugzilla.mozilla.org/show_bug.cgi?id=854627) that asm.js needs to solve its startup issues, as type-checking and generating native code for the whole module takes noticable time if its source is several megabytes. This API is geared towards off-thread compilation and ability to cache generated native code.

<p><small>[Here it should be noted that normal JIT does not have issues with off-thread and lazy compilation and solves these issues transparently]</small></p>

Grau ist alle Theorie
---------------------

Summarizing my concerns:

* **Performance side**: I am concerned that asm.js might negatively impact the size of JavaScript's performance sweet spot. In 6-12 months from now I would like to discover that I am wrong. How? An arbitrary piece of emscripten compiled code should execute with the same speed with or with out `"use asm"` annotation. I don't believe that anything like asm.js is needed to generate highly efficient native code, it's a leaky abstraction. Neither do I want developers to be penalized because they forgot a single `+` sign somewhere when cranking out asm.js style code manually.

* **Bytecode side**: I am concerned that we are trying to hide a bytecode inside a normal high-level language. Even more: we are trying to enrich a high-level language with features that only bytecode needs. If I believed that JavaScript has already hit a performance ceiling that it cannot surpass I would step forward and propose a bytecode that can go beyond that ceiling. But I don't believe that, see above.

<p><small>[At this point I have spent several hours writing these things down and I ate all the food that I stashed for Easter holidays. I am starting to think that I failed to clearly convey my thoughts and my feelings so it will be appropriate to starve to death. Thanks for reading anyway.]</small></p>

<p><span style=" color: white; border: 1px #7A0026 solid; padding: 0px 2px; background: #7a0026;">Update 18 July 2013</span> I have been told that my post can be read as if I am arguing that idiomatic JavaScript can easily achieve performance of asm.js-style code. I would like to clarify that this is not  what I am trying to say here. Without a doubt asm.js-style code comes with its own benefits: it eliminates non-trivial JavaScript objects and automatic memory management from the picture, reducing things to arithmetic and typed array manipulation. This reduces the pressure on the garbage collector, similar to manual JS-object pooling, and allows to avoid obscure corner cases in heuristics that are used by VMs to make inherently shapeless JavaScript objects fast. Thus asm.js-style code indeed has certain performance advantages over idiomatic JavaScript code (I argued the same <a href="http://mrale.ph/blog/2011/11/05/the-trap-of-the-performance-sweet-spot.html">over a year ago</a>) and discussing whether or not similar gains can be achieved by pure restructuring of the idiomatic code and advances in JIT compilation is out of scope for this post. </p>

This post concentrates on my belief that asm.js-style code can be JIT compiled without reliance on "use asm" and show performance comparable to AOT-compiled (think OdinMonkey) asm.js code. This is what I am arguing: asm.js in general and "use asm" in particular are not needed because JIT compilers can and should infer this information purely from JavaScript semantics. Instead we are being forced into false language dichotomy, without actually gaining access to a new shiny bytecode / language and still confined to JavaScript limitations.

At the same time I strongly believe that JIT compilers should strive to achieve **continuous performance** in the sense that *reasonable* perturbations to the input source should cause *reasonable* changes in the performance. Programmer must not be forced to write meaningless `e = +e` to tell VM that `e` is a double. In the *right* world there should be no difference in performance between the following two ways of doing the same thing:

{% highlight javascript %}
// Fully typed asm.js-style
var x = (function () {
  "use asm";
  var floor = stdlib.Math.floor;
  function x(e) {
    e = +e;
    // This is what you need to write in FF Nightly 25.0a1 (2013-07-18)
    // to coerce result of floor to integer and return it
    // if you what the code to validate as asm.js code.
    return ~~+floor(e)|0;
  }
  return { x: x };
})(window).x;
{% endhighlight %}

{% highlight javascript %}
// Reasonable-style
function x(e) { return floor(e)|0; }
{% endhighlight %}

