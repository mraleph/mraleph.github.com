---
layout: blogpost
title: Performance tuning as the art of weather forecast
date: 2013-04-29
---

Sometimes are I am genuinely surprised by my own inability to predict which snippet of code will run faster on V8 despite the fact that I know V8 internals quite well. It feels like leaving umbrella at home and finding myself under a cold rain, because in the morning I was expecting a clear sunny day.

This Sunday I found myself under one of those "performance rains" when I played with a jsperf snippet by [Calvin Metcalf](https://twitter.com/CWMma) that was comparing `i * i` to `Math.pow(i, 2)`.

I am not giving the link to his test case right away because I would like to play a small quiz with you first.

Here are two cases that I decided to measure:

{% highlight javascript %}
run({
  'Math.pow(i, 2)': function () {
    var sum = 0;
    for (var i = 0; i < 100; i++) {
      sum += Math.pow(i, 2);
    }
    if (sum !== 328350) throw new Error("oops");
  },

  'i * i': function() {
    var sum = 0;
    for (var i = 0; i < 100; i++) {
      sum += i * i;
    }
    if (sum !== 328350) throw new Error("oops");
  },
});
{% endhighlight %}

As you can see they are just computing sum of squares. Both case also check that the `sum` is correct both to verify that the code is doing the right thing and prevent DCE. A more advanced compiler can still sacrifice compilation time and constant fold the whole loop but V8 does not, so I did not try to guard against optimizations any further.

<p><small>[In fact at the moment V8 would not be able to DCE these computations even if I were not checking `sum` after the loop because it is <em>scared</em> by variable assignments. Nevertheless I still like to have my benchmarks verified at completion to catch bug in the optimizer if anything.]</small></p>

Usually when I need to quickly measure performance I use a relatively naive approach with two loops: one for warm up a function and another one to measure performance of the optimized code. This time however I decided to additionally run my code through [Benchmark.js](http://benchmarkjs.com/) which is a much more sophisticated benchmarking framework that powers [jsPerf](http://jsperf.com) itself.

{% highlight javascript %}
load("benchmark.js");  // from https://raw.github.com/bestiejs/benchmark.js/v1.0.0/benchmark.js

// Naive measuring loop that invokes the same function big number of times.
function measure(name, f) {
  var N = 1e6;
  try {
    // Warm up.
    for (var i = 0; i < 1e3; i++) f();

    // Timed loop.
    var start = Date.now();
    for (var i = 0; i < N; i++) f();
    var end = Date.now();

    // Report ops/sec just like Benchmark.js does it.
    // Use Benchmark.formatNumber helper to get a pretty number format.
    var result = (N * 1000 / (end - start));
    print("[naive] "+ name + " x " +
          Benchmark.formatNumber(result.toFixed(0)) + " ops/sec.");
  } catch (e) {
    print("[naive]" + name + " x " + e);
  }
}

// Take dictionary containing benchmarks and run them first naively and
// then
function run(benchmarks) {
  // First use naive measuring loop.
  Object.keys(benchmarks).forEach(function (key) {
    measure(key, benchmarks[key]);
  });

  // Now run benchmarks as a Benchmark.js suite: add them to the suite
  // and run.
  var suite = new Benchmark.Suite;
  Object.keys(benchmarks).forEach(function (key) {
    suite.add(key, benchmarks[key]);
  });
  suite.on('cycle', function(event) {
    print("[benchmark.js] " + event.target);  // Report result.
  });
  suite.run();
}
{% endhighlight %}

<div><span style=" color: white; border: 1px #7A0026 solid; padding: 0px 2px; background: #7a0026;">Update 30 April 2013</span> Notice that measurements below apply to a concrete version of Benchmark.js, <a href="https://twitter.com/jdalton">John-David Dalton</a> already <a href="https://github.com/bestiejs/benchmark.js/commit/dbaf5931b7667f45e8971505867c5c98c7c8b29a">pushed changes</a> into the development branch of the library that change described behavior. Details available at the end of the post.</div>

When I run test cases in the fresh build of V8's shell I saw the following results:

<pre>
% out/ia32.release/d8 --trace-opt test.js
[naive] Math.pow(i, 2) x 4,716,981 ops/sec.
[naive] i * i x 5,434,783 ops/sec.
[benchmark.js] Math.pow(i, 2) x <span style="color: #F68E55;">2,644,802</span> ops/sec <span style="color: red;">&plusmn;44.10%</span> (37 runs sampled)
[benchmark.js] i * i x <span style="color: #F68E55;">3,233,574</span> ops/sec <span style="color: red;">&plusmn;9.14%</span> (58 runs sampled)
</pre>

Whoa. Can you feel these cold rain drops starting to touch your skin?

There are two questions that immediately pop here:

* Why results reported by Benchmark.js are *lower* than those reported by naive measuring?
* Why results reported by Benchmark.js have high (in `Math.pow` case *enormous*) variance?

By coincidence I found the answer to both of these questions earlier last week when I encountered them for completely unrelated jsPerf test case. This answer follows from another fundamental question that everybody should ask when encountering strange performance issues:

Are we even running optimized code?
-----------------------------------

Before we start digging into this question lets learn a bit about Benchmark.js. How does it run test cases?

It turns out that for `i * i` test case library would compile a JavaScript function that looks like this (I am shortening things a bit):

{% highlight javascript %}
function (t) {
  var r, s, m = this, f = m.fn, ii = m.count, n = t.ns;
  s = new n;
  while (ii--) {
    var sum = 0;
    for (var i = 0; i < 100; i++) {
      sum += i * i;
    }
    if (sum !== 328350) throw new Error("oops");
  }
  r = (new n-s) / 1e3;
  return { elapsed: r }
}
{% endhighlight %}

As you can notice Benchmark.js directly inlined benchmark body *as text* into timed loop. If benchmark has `setup` and `teardown` phases they would be inlined in the same way but would reside outside of the timed region.

<p><small>[That's why you can declare local variables in <code>setup</code> phase and reference them from the benchmark body despite the fact that both of them look like separate functions.]</small></p>

But there is another thing to know about Benchmark.js: it compiles a new measuring function for every collected sample. For example above it said that 58 runs were sampled for `i * i` and each run was using a newly compiled measuring function with *the same source*.

Can this confuse V8? Yes, in fact it can. If we trace compilation with `--trace-opt` you will see a lot of lines like:

    [marking  0x49f080bc for recompilation, reason: hot and stable, ICs with typeinfo: 11/14 (78%)]
    [optimizing:  / 49f080bd - took 0.048, 0.207, 0.064 ms]

and sometimes

    [marking  0x49f42550 for recompilation, reason: hot and stable, ICs with typeinfo: 11/14 (78%)]
    [disabled optimization for , reason: optimized too many times]

What happens here is an unfortunate result of interaction between V8's optimization heuristics, on-stack replacement (OSR), compilation cache and optimized code cache:

* all measuring functions for the same test case have the same code so compilation always hits V8's compilation cache and all returned closures are all attached to the same `SharedFunctionInfo`;
* when measuring function is run it becomes very hot and gets optimized while running via OSR;
* however code generated for OSR is never placed into optimized code cache because code produced by OSR might be slightly worse;
* number of time function was optimized is counted on `SharedFunctionInfo`, eventually this count reaches threshold (`10` times) put in place to limit amount of time spent recompiling code and optimizations are disabled: as the result framework collects a time sample for unoptimized code which can much slower than samples for optimized code;
* hotness of a function is also counted on `SharedFunctionInfo`, eventually measuring function becomes super-hot and V8 enables optimizations again, and the cycle repeats.

There are various ways to fix this issue in V8 (star [Issue 2637](
https://code.google.com/p/v8/issues/detail?id=2637) if you would like to track the progress) but before it is fixed I have to resort to a workaround to reduce the variance and get the score for optimized code: I'll but the limit of optimizations to a higher value.

<pre>
% out/ia32.release/d8 <span style="color: #8493CA;">--max-opt-count=1000</span> test.js
[naive] Math.pow(i, 2) x 4,739,336 ops/sec.
[naive] i * i x 5,649,718 ops/sec.
[benchmark.js] Math.pow(i, 2) x <span style="color: #329555;">4,879,497</span> ops/sec <span style="color: #329555;">&plusmn;0.64%</span> (68 runs sampled)
[benchmark.js] i * i x <span style="color: #F68E55;">3,789,545</span> ops/sec <span style="color: #329555;">&plusmn;0.88%</span> (69 runs sampled)
</pre>

Hmm. That's quite unexpected is not it? The rain just turned into a hail. Variance and performance score has improved, but `i * i` is now slower than `Math.pow` when benchmarked with Benchmark.js.

Disassembly is compiler engineer's best friend
----------------------------------------------

<p><small>[disassembly can be obtained from V8 with `--print-opt-code --code-comments` if V8 was built with `disassembler=on`]</small></p>

Looking at the disassembly for `i * i` case in Benchmark.js variant reveals quite an unfortunate register allocation decision on V8 part (I have prettified assembly to make it easier to read):

{% highlight nasm %}
loop:
  ;; spill local variables
  mov [ebp + 0xa4], eax ;; eax is sum
  mov [ebp + 0xac], ecx ;; ecx is i

  ;; if (i >= 100) goto done
  cmp ecx,0x64
  jnl done

  ;; interrupt check (e.g. to interrupt long running loops)
  cmp esp,[StackLimit]
  jc ->interrupt

  ;; edx = i * i
  mov edx,ecx
  imul edx,ecx
  jo ->deopt  ;; deoptimize if multiplication overflowed 32bit

  ;; ecx = sum + edx
  mov ecx,eax
  add ecx,edx
  jo ->deopt  ;; deoptimize if addition overflowed 32bit

  ;; restore i to eax
  mov eax,[ebp+0xac]

  ;; eax = eax + 1
  add eax,0x1

  ;; now eax and ecx are swapped :-(
  ;; swap them back
  xchg eax, ecx
  jmp loop

done:
{% endhighlight %}

and the register allocation in *naive* case looks much better with no `xchg` or restoring from spill slot

{% highlight nasm %}
loop:
  mov [ebp+0xe8],ecx  ;; ecx is sum
  mov [ebp+0xec],eax  ;; eax is i

  ;; if (i >= 100) goto done
  cmp eax,0x64
  jnl done

  ;; interrupt check
  cmp esp,[StackLimit]
  jc ->interrupt

  ;; edx = i * i
  mov edx,eax
  imul edx,eax
  jo ->deopt

  ;; ebx = sum + edx
  mov ebx,ecx
  add ebx,edx
  jo ->deopt

  ;; i += 1
  add eax,0x1

  ;; move sum to ecx where it is expected
  mov ecx,ebx
  jmp loop
done:
{% endhighlight %}

the reason why register allocation decisions are different is because surrounding code in the Benchmark.js case affects the state of the register allocation (at the moment V8 uses linear scan).

Various heuristics can be applied to solve this issue in V8... But can anything be done in JavaScript source to help register allocator?

Why, yes, there is a small trick in my sleeve. It is completely unobvious unless of course you know by heart how register allocator makes its decisions:

{% highlight javascript %}
  'sum = i * i + sum': function() {
    var sum = 0;
    for (var i = 0; i < 100; i++) {
      sum = i * i + sum;
    }
    if (sum !== 328350) throw new Error("oops");
  },
{% endhighlight %}

If we benchmark this case along side with others we'll get

<pre>
% out/ia32.release/d8 --max-opt-count=1000 test.js
[naive] Math.pow(i, 2) x 4,807,692 ops/sec.
[naive] i * i x 5,555,556 ops/sec.
[naive] sum = i * i + sum x 5,617,978 ops/sec.
[benchmark.js] Math.pow(i, 2) x 4,971,911 ops/sec &plusmn;0.60% (70 runs sampled)
[benchmark.js] i * i x 3,842,327 ops/sec &plusmn;0.45% (70 runs sampled)
[benchmark.js] sum = i * i + sum x <span style="color: #F68E55;">5,834,128</span> ops/sec &plusmn;0.76% (69 runs sampled)
</pre>

WEEEEEELL. Now if you want to [troll](http://alltheragefaces.com/img/faces/large/troll-troll-face-l.png) your colleagues you can just show them that `sum = i * i + sum` is faster than `sum += i * i` on Chrome and ask them for an explanation.

To put it simply V8's register allocator can easily reuse registers when temporary value comes as a first operand to some operations. Hence when compiling `i * i + sum` it can reuse register of `i * i` for the result of addition while in `sum + i * i` it can't. Unfortunately full explanation is a bit lengthy.

Morale of this story is quite simple...

Wait! Why `Math.pow` is slower in the first place?
--------------------------------------------------

Indeed it's a bit too early for the morale. Looking at the IR of the loop body for the `Math.pow(i, 2)` case reveals a surprising picture:

<pre class="highlight" style="border-top: 1px solid #ccc; border-bottom: 1px solid #ccc;">
<table style="border-spacing: 0px; border-collapse: collapse;">
<tr><td style="border-right: 1px solid #ccc;"><span class="nf">B4</span></td><td></td></tr>
<tr><td style="border-right: 1px solid #ccc;"></td><td><span class="nf">BlockEntry</span></td></tr>
<tr><td style="border-right: 1px solid #ccc;"></td><td><span class="nf">Simulate</span> id=30</td></tr>
<tr><td style="border-right: 1px solid #ccc;"></td><td><span class="nf">StackCheck</span></td></tr>
<tr><td style="border-right: 1px solid #ccc;"><span class="nb">i35</span></td><td><span class="nf">Mul</span> <span class="nb">i15</span> <span class="nb">i15</span> ! -0? <span class="c1">;; this is Math.pow(i, 2)</span></td></tr>
<tr><td style="border-right: 1px solid #ccc;"><span class="nb">d67</span></td><td><span class="nf">Change</span> <span class="nb">i35</span> i to d</td></tr>
<tr><td style="border-right: 1px solid #ccc;"><span class="nb">d37</span></td><td><span class="nf">Add</span> <span class="nb">d14</span> <span class="nb">d67</span> ! <span class="c1">;; this is sum += Math.pow(i, 2)</span></td></tr>
<tr><td style="border-right: 1px solid #ccc;"><span class="nb">i40</span></td><td><span class="nf">Add</span> <span class="nb">i15</span> <span class="nb">i39</span></td></tr>
<tr><td style="border-right: 1px solid #ccc;"></td><td><span class="nf">Simulate</span> id=26, var[3] = <span class="nb">i40</span> var[2] = <span class="nb">d37</span></td></tr>
<tr><td style="border-right: 1px solid #ccc;"></td><td><span class="nf">Goto</span> B2</td></tr></table></pre>

Surprises again. Hydrogen is actually *smart enough* to recognize `Math.pow(i, 2)` and convert it to a multiplication (additionally it can also [recognize](https://code.google.com/p/v8/source/browse/branches/bleeding_edge/src/hydrogen.cc?r=14464#9079) `0.5` and `-0.5` cases). However instead of using an integer addition it decides to keep `sum` as a double value and use double addition.

This happens because `!==` comparison that follows the loop *tells* optimizing compiler that it was used to compare double values and optimizing compiler decides (for safety) keep sum in the double because it thinks it can overflow into the double range.

But why does `!==` think that it saw a double value while it is obvious that sum is always an integer? Well the reason is that type feedback for `!==` is not fine grained enough to distinguish between "real" doubles and `int32` values hidden in the double. So when `Math.pow(i, 2)` returns an integer value as a double (`HeapNumber`) this makes sum to turn into double (`HeapNumber`) and at the end confuses the comparison. Addition is smart enough to know that things that it adds are `int32` values but feedback from `!==` persuades compiler that it needs to be careful.

If we either remove verification or "unwrap" the double returned by `Math.pow(i, 2)` by truncating it optimizing compiler will start producing code identical to the `i * i` case.

{% highlight javascript %}
  'Math.pow(i, 2) [no check]': function () {
    var sum = 0;
    for (var i = 0; i < 100; i++) {
      sum += Math.pow(i, 2);
    }
  },

  'Math.pow(i, 2)|0': function () {
    var sum = 0;
    for (var i = 0; i < 100; i++) {
      sum += Math.pow(i, 2)|0;
    }
    if (sum !== 328350) throw new Error("oops");
  },
{% endhighlight %}

<pre>
% out/ia32.release/d8 --max-opt-count=10000 test.js
[naive] Math.pow(i, 2) x 4,854,369 ops/sec.
[naive] Math.pow(i, 2) [no check] x 5,649,718 ops/sec.
[naive] Math.pow(i, 2)|0 x 5,434,783 ops/sec.
[naive] i * i x 5,649,718 ops/sec.
[naive] sum = i * i + sum x 5,586,592 ops/sec.
</pre>

Desert: `Math.pow` &agrave; la cache.
-------------------------------------

Are there any other mysteries we can squeeze out of this simple benchmark?

Why yes, there are :-)

One of the jsPerf tests that prompted me to start looking into these was caching `pow` in a local variable as asm.js module pattern demanded.

{% highlight javascript %}
  'pow(i, 2)': function () {
    var pow = Math.pow;
    var sum = 0;
    for (var i = 0; i < 100; i++) {
      sum += pow(i, 2);
    }
  },
{% endhighlight %}

We have seen that optimizing compiler is more than capable of optimizing `Math.pow` lookup away so surely it caching `pow` manually should not heart performance? Right?

Unfortunately wrong.

<pre>
% out/ia32.release/d8 --max-opt-count=10000 test.js
[naive] pow(i, 2) x <span style="color: red;">650,618</span> ops/sec.
[naive] Math.pow(i, 2) x 4,739,336 ops/sec.
</pre>

This happens because V8's optimizing compiler has to separate methods to perform inlining of recognized built-ins: [`TryInlineBuiltinMethodCall`](https://github.com/v8/v8/blob/6faa6b317ab029c8379eda520a3ba6d28bbd5258/src/crankshaft/hydrogen.cc#L8716) handles inlining at method invocation `o.m()` and [`TryInlineBuiltinFunctionCall`](https://github.com/v8/v8/blob/6faa6b317ab029c8379eda520a3ba6d28bbd5258/src/crankshaft/hydrogen.cc#L8649) that handles inlining at free function invocation `f()`.

Right now `Math.pow` is handled only in `TryInlineBuiltinMethodCall` so it is not recognized or even inlined when it is called as a free function.

Morale
------

NOW it is time for morale. Which is quite simple: measuring things is hard, predicting performance without measuring is even harder. Performance is like weather, requires gut feeling and hi-tech meteorological satellites to predict the rain reliably.

<small>And here is <a href="http://jsperf.com/pow2/3">original</a> jsPerf case that prompted this blog post.</small>


<h2><div><span style="color: white; border: 1px #7A0026 solid; padding: 0px 2px; background: #7a0026; font-size: 0.5em;">Update 30 April 2013</span></div>Benchmark.js hardens mangling scheme</h2>

With this [commit](https://github.com/bestiejs/benchmark.js/commit/dbaf5931b7667f45e8971505867c5c98c7c8b29a) Benchmark.js no longer generates exactly the *same* source for every measuring function: each sample is collected using a newly compiled function in which identifiers are mangled with a id unique for that sample.

This prevents V8 (and I suspect other engines) from reusing even non-optimized compiled code. At the same time it prevents V8 from manifesting [Issue 2637](
https://code.google.com/p/v8/issues/detail?id=2637) because measuring functions are no longer backed by the same `SharedFunctionInfo`.

With updated version of the library I get the following result on my testing script *without bumping `--max-opt-count`*:

<pre>
% out/ia32.release/d8 test.js
[naive] pow(i, 2) x 643,501 ops/sec.
[naive] Math.pow(i, 2) x 4,608,295 ops/sec.
[naive] Math.pow(i, 2) [no check] x 5,464,481 ops/sec.
[naive] Math.pow(i, 2)|0 x 5,524,862 ops/sec.
[naive] i * i x 5,649,718 ops/sec.
[naive] sum = i * i + sum x 5,555,556 ops/sec.
[benchmark.js] pow(i, 2) x 640,942 ops/sec &plusmn;1.02% (65 runs sampled)
[benchmark.js] Math.pow(i, 2) x 4,671,581 ops/sec &plusmn;0.88% (68 runs sampled)
[benchmark.js] Math.pow(i, 2) [no check] x 5,074,812 ops/sec &plusmn;1.19% (66 runs sampled)
[benchmark.js] Math.pow(i, 2)|0 x 3,756,236 ops/sec &plusmn;0.70% (67 runs sampled)
[benchmark.js] i * i x 3,677,572 ops/sec &plusmn;0.49% (66 runs sampled)
[benchmark.js] sum = i * i + sum x 5,658,358 ops/sec &plusmn;1.02% (66 runs sampled)
</pre>

As you can see naive and Benchmark.js results are aligned much better now and the only difference that remained is between `sum = sum + i * i` and `sum = i * i + sum` cases which is explained by the register allocator decisions and is not affected by change in the mangling scheme.

<p><small>[Note that this update is yet to come to jsPerf]</small></p>
