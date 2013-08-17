---
layout: blogpost
title: Hidden classes vs jsPerf
date: 2013-08-14
---

Hello JavaScript programmers,

Look at [this](http://jsperf.com/closure-vs-property/4) jsPerf test case.

Now back to me.

Now back at [another revision](http://jsperf.com/closure-vs-property/5) of the same test case.

Now back to me.

Is it *confusion* that I see in your eyes?

Lets resolve it.

To keep this story short I will assume that you read my other posts about V8's internals (at least [this](http://mrale.ph/blog/2012/06/03/explaining-js-vms-in-js-inline-caches.html), [this](http://mrale.ph/blog/2012/09/23/grokking-v8-closures-for-fun.html), [this](http://mrale.ph/blog/2012/12/15/microbenchmarks-fairy-tale.html) and [this](http://mrale.ph/blog/2013/04/29/performance-tuning-as-weather-forecast.html) ) and have an idea about how inline caches, hidden classes and closures work in V8, how jsPerf benchmarks your code by generating a function from your test case code and why microbenchmarks are bad.

We start by throwing together a simple standalone test case that can be run in the `d8` shell:

{% highlight javascript %}
// Load tip-of-the-tree versions of lodash and benchmark.js
load("lodash.js");
load("benchmark.js");

Benchmark.prototype.setup = function() {
  function ClosureColor(name) {
    // Have no choice but to add these methods to the instance
    this.getName = function () {
        return name;
    };
    this.setName = function (n) {
        name = n;
    };
  }
  var closureColor = new ClosureColor('green');

  function PrototypeColor(name) {
    this._name = name;
  }

  PrototypeColor.prototype.getName = function () {
    return this._name;
  };

  PrototypeColor.prototype.setName = function (n) {
    this._name = n;
  };

  var prototypeColor = new PrototypeColor('green');
};

var suite = new Benchmark.Suite;
suite
  .add('Closure', function () {
    var name = closureColor.getName();
    closureColor.setName('blue');
  })
  .add('Prototype', function () {
    var name = prototypeColor.getName();
    prototypeColor.setName('blue');
  })
  .on('cycle', function (event) { print(event.target); })
  .run();
{% endhighlight %}

The test case runs just fine and reports low variance which indicates that there is no problem with optimization being disabled for functions collecting timing samples:

<pre>
&#8750; out/ia32.release/d8 test.js
Closure x 427,071,038 ops/sec &plusmn;1.14% (67 runs sampled)
Prototype x <span style="color: gold;">332,008,541</span> ops/sec &plusmn;0.99% (65 runs sampled)
</pre>

What in the name of adaptive compilation is going on here? Did not everyone including me tell before that it is better to use classical prototype pattern as *this is what VM optimize for*?

Diving into IR (take a deep breath)
-----------------------------------

Lets compare hydrogen IR that V8 generated for benchmarking loops in both cases

<small>[I am stripping away some cruft in both cases to highlight the difference]</small>

<pre class="hydrogen">
     ;; Closure case
B7
     CheckHeapObject t114        ;; (*)
t157 CheckMaps t114 [0x5ad083c9] ;; (*)
t158 Constant {FixedArray[5]}
     EnterInlined ClosureColor.getName
t161 LoadContextSlot t158[4]
v162 LeaveInlined
     Goto B8

B8
t168 Constant "blue"
v173 EnterInlined ClosureColor.setName
v174 StoreContextSlot t158[4] = t168 changes[ContextSlots]
v176 LeaveInlined
v178 Goto B9
</pre>

<pre class="hydrogen">
     ;; Prototype case
B7
t156 CheckHeapObject t116        ;; (*)
     CheckMaps t116 [0x5ad1ab41] ;; (*)
t158 Constant {FixedArray[86]}
     EnterInlined PrototypeColor.getName
t163 LoadNamedField t116._name
     LeaveInlined
     Goto B8

B8
t170 Constant "blue"
     EnterInlined PrototypeColor.setName
     CheckMaps t116 [0x5ad1a989,0x5ad1ab41] ;; (?)
     StoreNamedField t116._name = t170
     LeaveInlined
     Goto B9
</pre>

There are numerious code quality issues here:

* Checks marked as `(*)` I would expect to be hoisted out of the loop via LICM because there is nothing in the loop body that could potentially affect them;
* Instruction marked as `(?)` I was not expecting to see at all. It's a polymorphic check verifying that value `t116` has *either* one of two hidden classes. It looks especially out of place because it is dominated by another less general map check so CSE should have eliminated it. This instruction is the main difference between `Closure` and `Prototype` cases.

Source of polymorphism
----------------------

Actually I lied when I said that I was not expecting to see a polymorphic check *at all*. In fact previously, before [John-David Dalton](https://twitter.com/jdalton) fixed mangling scheme used by Benchmark.js I was constantly seeing highly polymorphic test cases poping up.

To understand how interaction between jsPerf and V8 hidden classes can lead to a polymorphic code lets briefly remember a couple of things.

Hidden classes
--------------

<img src="/images/2013-08-14/maps.png" class="centered"/>

V8 uses *hidden classes* (called *maps* internally) to capture object structure as it's *shape* is being mutated. Each hidden class fully describes object's layout and contains additional information about it e.g. it points to object's prototype. Object's hidden class changes as new properties are being added to it. Individual hidden classes describing *shapes* that object went through are wired together with *transitions* so that runtime system could find them if some other object arrives to the same shape. This chain (or rather *dag*) of transitions usually starts at object's constructor which carries around so called *initial map*. Different constructors carry different initial maps.

Important thing to understand from this is that the code below will produce objects with different hidden classes because their constructors are different closures.

{% highlight javascript %}
function make() {
  function maker() { }
  return new maker();
}

var a = make(), b = make();
// a and b have different hidden classes because a new maker is created
// every time you execute make.
{% endhighlight %}

Inline Caches and Optimizing Compiler
-------------------------------------

<img src="/images/2013-08-14/ics.png" class="centered"/>

V8 has two separate compilers: a simple non-optimizing one (aka *full*) and an optimizing one. When code is compiled with a *full* compiler all operations with dynamic binding like property lookups get an *inline cache* (aka IC) that remembers what kind of objects it saw and adopts to them to ensure that the next time this IC sees the same kind of object it can perform operation quickly instead of figuring out what to do again. One thing to note here is that unoptimized code is shared by all instances of the same function literal which means that ICs and information collected by them is shared as well.

When the code becomes *hot* it gets recompiled with optimizing compiler that takes information collected by ICs and uses it to speculatively specialize code to handle only types that ICs saw. Specialization is guarded with *checks* that verify assumptions made optimizing compiler. After specialization compiler applies  classical techniques (CSE, LICM and so on), which make code even faster by eliminating different redundancies: for example repetitive guards inserted on earlier stages or repetitive loads from the property that does not change.

Adding things together
----------------------

To execute your test case Benchmark.js compiles it into a JavaScript code that looks approximately like this (I am intentionally writing certain things differently to highlight important parts):

{% highlight javascript %}
function (N) {
  /* code from setup section is here */
  var start = Date.now();
  for (var i = 0; i < N; i++) {
    /* test case code is here */
  }
  var end = Date.now();
  /* code from teardown section is here */
  return (end - start);
}
{% endhighlight %}

In fact it generates multiple copies of this code *each mangled using a unique identifier* to prevent underlying JavaScript VM from caching optimized version. Each copy is used to obtain a single timing sample for a test case. As can be seen above Benchmark.js sampled **67** runs of `Closure` case which means it compiled **67** uniquely mangled versions of benchmarking function. However each of those functions was run not once but *twice*.

Before running generated function with a big number of iterations `N` Benchmark.js [pretests](https://github.com/bestiejs/benchmark.js/blob/cbef3ad3c1dd04b87373717d3379c7ce6a446308/benchmark.js#L1691-L1695) it by executing it with `N = 1`.

Now the source of polymorphism is apparent: by executing benchmarking function twice, we executed setup section twice which each time produced objects with different hidden classes. Essentially hidden classes from pretest have flown into ICs and "polluted" them.

Wait! Why do we have both poly- and mono- checks?
-------------------------------------------------

The truth is some ICs (for property loads and calls) do not record the type of the very first object they see. When such IC is used for the first time it flips to a so called *premonomorphic* state and does not record the type it saw, only the next observed object will be recorded. Other ICs (for example ones used for stores) do not have premonomorphic state and start recording types immediately.

For our benchmark it means that pretest run transitions all load and call ICs into premonomorphic state while a store IC in `PrototypeColor.prototype.setName` becomes *monomorphic*. The benchmarking function is run the second time load and call ICs become monomorphic, but the store IC becomes *polymorphic* because it saw two distinct hidden classes. On the other hand `ClosureColor.prototype.setName` does not contain a store IC at all because context variable access in the absence of `eval` is not dynamically bound and is statically resolved by scope analysis even before optimizing compilation.

Here is an excerpt from the log generated by debug build of `d8` with `--trace-ic` flag.

<pre>
&#8750; out/ia32.release/d8 --trace-ic test.js
              ---&#9986;---
<em>// Closure case pretest run, calls to getName/setName are executed
// for the first time and become premonomorphic (.). No ICs inside functions.</em>
[CallIC in +370 at &lt;unknown&gt;:28 (0-&gt;.)#getName]
[CallIC in +394 at &lt;unknown&gt;:29 (0-&gt;.)#setName]
              ---&#9986;---
<em>// Closure case real run, calls to getName/setName are executed
// more and become monomorphic (1). No ICs inside functions.</em>
[CallIC in +370 at &lt;unknown&gt;:28 (.-&gt;1)#getName]
[CallIC in +394 at &lt;unknown&gt;:29 (.-&gt;1)#setName]
              ---&#9986;---
<em>// Prototype case pretest run, calls to getName/setName are executed
// for the first time and become premonomorphic. getName contains a load IC
// which becomes premonomorphic as well. setName has store IC which becomes
// monomorphic.</em>
[CallIC in +370 at &lt;unknown&gt;:28 (0-&gt;.)#getName]
[LoadIC in PrototypeColor.getName+33 at &lt;unknown&gt;:20 (0-&gt;.)#_name]
[CallIC in +394 at &lt;unknown&gt;:29 (0-&gt;.)#setName]
[StoreIC in PrototypeColor.setName+35 at &lt;unknown&gt;:24 (0-&gt;1)#_name]
              ---&#9986;---
<em>// Prototype case real run, previously premonomorphic ICs become
// monomorphic. Store IC inside setName on the other hand becomes
// polymorphic (P).</em>
[CallIC in +370 at &lt;unknown&gt;:28 (.-&gt;1)#getName]
[LoadIC in PrototypeColor.getName+33 at &lt;unknown&gt;:20 (.-&gt;1)#_name]
[CallIC in +394 at &lt;unknown&gt;:29 (.-&gt;1)#setName]
[StoreIC in PrototypeColor.setName+35 at &lt;unknown&gt;:24 (1-&gt;P)#_name]
</pre>

Why mono-check does not subsume poly-check?
-------------------------------------------

I was expecting `CheckMaps x, [A]` instruction to fully subsume any dominated `CheckMaps x, [A, ...]` instruction. However such optimization is simply not implemented in V8 at this moment.

Why inserted checks are not hoisted?
------------------------------------

This is a more interest question. V8 has a loop invariant code motion pass. Checks are obviously invariant, as nothing changes object's hidden classes in this loop. Why didn't LICM move them out?

After spending some time with debug `printf`'s I managed to figure out that this is a bug in the interaction between on-stack-replacement, graph building and LICM:

1. we decide to optimize benchmarking function while it is still running (which is a wise decision as it will be run only once with big iteration count);
2. when building graph we decide that certain property assignments in the setup section were not executed enough times for us to gather type feedback, so we insert a unconditional deoptimization instruction there;
3. compiler transitively propagates deoptimization mark through the dominators tree, because he thinks that the code dominated by an unconditional deoptimization will never be executed;
4. LICM is disabled for the parts of the graph that are marked as "deoptimizing".
5. execution enters resulting optimized version through OSR entry so it skips deoptimization instruction and proceeds to run loop that was not really all that optimized.

If I rewrite setup section to work around this bug by obstructing the control flow:

{% highlight javascript %}
Benchmark.prototype.setup = function() {
  function mk1() {
    function ClosureColor(name) {
      // Have no choice but to add these methods to the instance
      this.getName = function () {
          return name;
      };
      this.setName = function (n) {
          name = n;
      };
    }
    return new ClosureColor('green');
  }

  function mk2() {
    function PrototypeColor(name) {
      this._name = name;
    }

    PrototypeColor.prototype.getName = function () {
      return this._name;
    };

    PrototypeColor.prototype.setName = function (n) {
      this._name = n;
    };

    return new PrototypeColor('green');
  }

  var closureColor = mk1();
  var prototypeColor = mk2();
};
{% endhighlight %}

then all checks (including a polymorphic one in the `Prototype` case) are hoisted from both loops leaving only stores and loads inside and as the result performance of both becomes the same:

<pre>
&#8750; out/ia32.release/d8 test2.js
Closure x <span style="color: green;">603,675,310</span> ops/sec &plusmn;0.60% (67 runs sampled)
Prototype x <span style="color: green;">602,932,682</span> ops/sec &plusmn;0.84% (66 runs sampled)
</pre>

So our preliminary conclusion would be:

* Initial difference in performance between two test cases was caused by the invisible polymorphism that "leaked" from the pretest run.
* Overall performance was degraded due to LICM being disabled due to incorrect propagation of the "deoptimizes" marking through the graph.

Making test case more realistic
-------------------------------

In the real world it is unlikely that application would create `ClosureColor` and `PrototypeColor` again and again. In most cases they will be created once and used to produce multiple objects.

{% highlight javascript %}
function ClosureColor(name) {
  // Have no choice but to add these methods to the instance
  this.getName = function () {
      return name;
  };
  this.setName = function (n) {
      name = n;
  };
}

function PrototypeColor(name) {
  this._name = name;
}

PrototypeColor.prototype.getName = function () {
  return this._name;
};

PrototypeColor.prototype.setName = function (n) {
  this._name = n;
};

Benchmark.prototype.setup = function() {
  var closureColor = new ClosureColor('green');
  var prototypeColor = new PrototypeColor('green');
};
{% endhighlight %}

<pre>
&#8750; out/ia32.release/d8 test3.js
Closure x <span style="color: red;">66,993,950</span> ops/sec &plusmn;1.19% (65 runs sampled)
Prototype x <span style="color: green;">605,601,154</span> ops/sec &plusmn;0.60% (67 runs sampled)
</pre>

What just happened here? Nothing good. V8 usually tries to represent properties containing functions in a special way: put actual function values as *constant functions* on the hidden class. This allows them to perform as fast as methods in a more static language would. However right now this only works if you assign the very same function to the same property when producing a new object. `ClosureColor` assigns new closure each time which breaks V8's approach. A bit more detailed explanation is available in [my other post on closures](http://mrale.ph/blog/2012/09/23/grokking-v8-closures-for-fun.html).

Benchmarking microhorse
-----------------------

I would like to conclude beating microbenchmarking horse again. It is hard to write meaningful microbenchmarks. It is hard to interpret their results. Please don't do it.

This benchmark might look like it is comparing different class emulation approaches, but we saw that it does not and ultimately several months in the future it might simply become an empty loop benchmark once JavaScript VMs implement *allocation sinking*.

<script type="text/javascript" src="/js/ir.js"></script>