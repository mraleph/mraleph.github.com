---
layout: blogpost
title: &#956;benchmarks fairy tale
date: 2012-12-15
webfonts: [UnifrakturMaguntia]
---

Imagine for a moment that you are a modern day hero. A prince or a princess adept in JavaScript programming traveling through enchanted world and searching for the World's Salvation, the Ultimate Love or the well guarded recipe of [Siberian dumplings](http://en.wikipedia.org/wiki/Pelmeni).

Sooner or later you encounter a merciless [Sphinx](http://en.wikipedia.org/wiki/Sphinx) who asks you the simplest question you've ever heard in your life: **"What is the cost of accessing the `length` property of a string value in JavaScript running in the recent version of Chrome?"**

You are a seasoned adventurer and your pockets are full of tools. You throw together a simple [jsPerf test case](http://jsperf.com/primitive-value-string-vs-wrapper-object-string-length) and tell Sphinx the answer.

And Sphinx eats you.

<div style="font-family: UnifrakturMaguntia; font-weight: bold;">THE END</div>

Compilers vs. &#956;benchmarks
------------------------------

It's a fairy tale inside the fairy tale really. Microbenchmarks are both the best friends and worst foes of compilers. Nothing helps you to solve a performance problem better than a microbenchmark demonstrating it. Nothing spoils your day more than a microbenchmark that is used to derive incorrect conclusions.

As compilers get smarter it becomes harder to write a microbenchmark that would give you an answer to even the simplest question. As Robert Sheckley wrote in his short story [Ask a Foolish Question](ftp://ibiblio.org/pub/docs/books/gutenberg/3/3/8/5/33854/33854-h/33854-h.htm): *In order to ask a question you must already know most of the answer.*

Back in the glorious days of interpreted JavaScript you could write:

{% highlight javascript %}
function CostOfLoop(N) { /* let the cost of empty loop be $C_{loop}$ */
  var start = Date.now();
  for(var i = 0; i < N; i++) {
    /* Nothing to do here. */
  }
  var end = Date.now();
  return (end - start);
}

function CostOfLengthPlusLoop(N) {
  var str = "Hello";
  var res = 0;

  var start = Date.now();
  for(var i = 0; i < N; i++) {
    res = str.length; /* let cost of a single operation be $C_{op}$ */
  }
  var end = Date.now();

  if (res !== 5) throw new Error("something is wrong");
  return (end - start);
}

function CostOfLength(N) {
  return (CostOfLengthPlusLoop(N) - CostOfLoop(N)) / N;
}

print(CostOfLength(1e5));
{% endhighlight %}

and get the answer you were searching for. This was backed by a simple mathematics: repeat action many times in the loop, measure how much that takes and then substract amount of time needed for the empty loop itself.

$$\frac{(N \cdot C_{op} + C_{loop}) - C_{loop}}{N} \approx C_{op}$$

But this mathematical tranquility ended when JIT compilers arrived from <a href="http://en.wikipedia.org/wiki/Self_(programming_language)">the other universe</a> and started optimizing things.

Loop-invariant code motion
--------------------------

There are many ways for an optimizing compiler to spoil your calculations. One of them is the *loop-invariant code motion* usually abbreviated as LICM. This optimization identifies expressions that produce the same value on all loop iterations and hoists them out of the loop.

In fact many JavaScript programmers are actually performing LICM by hand when they manually move `array.length` expression out of the loop condition and keep in the temporary variable during iteration.

Implementation of the LICM is usually pretty straightforward. It involves figuring out dependencies between different expressions inside the loop. For example stores can affect loads from the same location making them non-invariant if the stored value itself is non-invariant. Calls to function might potentially have completely unknown effects and so on. You can take a look at V8's [LICM pass](https://code.google.com/p/v8/source/browse/branches/bleeding_edge/src/hydrogen.cc?r=13193#1907) if you'd like to see how it can be done.

<small>[IonMonkey as well <a href="http://hg.mozilla.org/mozilla-central/file/c8a1314aa449/js/src/ion/LICM.cpp">implements</a> a variation of the classical LICM. PyPy and LuaJIT2 tracing JITs apply a different approach: they combine loop peeling with CSE to achieve effect similar to LICM. You can read more in a paper <a href="https://bitbucket.org/pypy/extradoc/src/98f94d389f25/talk/dls2012/licm.pdf">Loop-Aware Optimizations in PyPy's Tracing JIT</a> from PyPy developers. There were some indications that JavaScriptCore might go the <a href="http://lists.webkit.org/pipermail/webkit-dev/2012-February/019585.html">same route</a>.]</small>

Lets now take a look at the *intermediate representation* that V8's optimizing compiler generates for a nicely warmed up and optimized version of `CostOfLength`:

{% highlight javascript %}
// WARM UP
for (var i = 0; i < 1000; i++) CostOfLength(1e5);
{% endhighlight %}

<pre>
<b>B0:</b>
  t4 = Parameter 1 <em>/* N */</em>
  Goto <b>B1</b>

<b>B1:</b>
  i20 = Constant 0
  i51 = Constant 1
  t19 = Constant "Hello"
  t25 = CallConstantFunction <em>Date.now</em>
  t51 = StringLength t19
  i142 = Change t51 tagged to int
  i138 = Change t4 tagged to int
  Goto <b>B2</b>

<b>B2:</b> <em>/* loop entry */</em>
  i32 = &#966;(i20, i142) <em>/* res */</em>
  i34 = &#966;(i20, i53)  <em>/* i */ </em>
  CompareIDAndBranch (i34 &lt; i138) goto (<b>B3</b>, <b>B5</b>)

<b>B3:</b>
  Goto <b>B4</b>

<b>B4:</b>
  StackCheck
  i53 = Add i34 i52 <em>/* i++ */</em>
  Goto <b>B2</b>
</pre>

<small>[I prettified hydrogen manually by throwing out some irrelevant details but did not remove anything important.]</small>

As you can see string length access was hoisted out of the loop entirely and is now sitting right above the loop entry block `B2`. This turned our pretty mathematical formula for $C_{op}$ into something strange:

$$\frac{(1 \cdot C_{op} + C_{loop}) - C_{loop}}{N} \approx \frac{C_{op}}{N} \approx 0$$

Hmm. This [does not look right](http://alltheragefaces.com/img/faces/large/misc-are-you-fucking-kidding-me-clean-l.png). No wonder Sphinx was not happy with the answer.

The only advice I can give here is to *avoid loop invariant expressions when trying to estimate cost of operations*.

Constant propagation
--------------------

This is another optimization that could have agitated the Sphinx but V8 does not apply it in this case.

The idea behind this optimization is even simpler than LICM: you just fold all constant expressions until only non-constant ones that depend on some runtime values or behavior remain. There are various well known and widely used forms of this optimization for example [Sparse Conditional Constant Propagation](http://dl.acm.org/citation.cfm?id=103136).

V8 in fact does a limited constant folding for numeric expressions during SSA graph construction phase. What would happen if it did the same for `StringLength` operation?

It's quite easy to try out by adding a simple canonicalization rule for `HStringLength` IR instruction:

{% highlight cpp %}
HValue* HStringLength::Canonicalize() {
  if (value()->IsConstant() &&
      HConstant::cast(value())->representation().IsTagged() &&
      HConstant::cast(value())->handle()->IsString()) {
    // If value is string then replace this instruction with length of that string.
    Handle<String> string_value =
        Handle<String>::cast(HConstant::cast(value())->handle());
    HConstant* length = new(block()->zone())
        HConstant(string_value->length(), Representation::Integer32());
    length->InsertBefore(this);
    return length;
  }
  return this;
}
{% endhighlight %}

With this trivial 14 lines change most of which is just boilerplate code `StringLength` disappears entirely from the optimized version of `CostOfLength` function and mathematics of the microbenchmark is distorted further:

<pre>
<b>B0:</b>
  t4 = Parameter 1 <em>/* N */</em>
  Goto <b>B1</b>

<b>B1:</b>
  i20 = Constant 0
  i51 = Constant 1
  t19 = Constant "Hello"
  t25 = CallConstantFunction <em>Date.now</em>
  t51 = StringLength t19
  i147 = Constant 5 <em>/* StringLength was evaluated during compilation! */</em>
  i138 = Change t4 tagged to int
  Goto <b>B2</b>

<b>B2:</b> <em>/* loop entry */</em>
  i32 = &#966;(i20, i147) <em>/* res */</em>
  i34 = &#966;(i20, i53)  <em>/* i */ </em>
  CompareIDAndBranch (i34 &lt; i138) goto (<b>B3</b>, <b>B5</b>)

<b>B3:</b>
  Goto <b>B4</b>

<b>B4:</b>
  StackCheck
  i53 = Add i34 i52 <em>/* i++ */</em>
  Goto <b>B2</b>
</pre>

$$\frac{(0 \cdot C_{op} + C_{loop}) - C_{loop}}{N} \approx \frac{0}{N} = 0$$

While V8 currently does not fold `StringLength` away example above demonstrates that it can be easily implemented. The advice here would be to *avoid constant expressions when trying to estimate cost of operations*.

Dead code elimination (DCE)
---------------------------

DCE is another optimization that is often mentioned in connection to *wrong microbenchmarking*. DCE tries to eliminate operations that have no observable effect on the rest of the program execution.

If a JavaScript applied DCE to our microbenchmark then both loops would just disappear from the program. The same would happen to any expression without side effects, computations which are done but never used etc.

At the moment V8 does not perform DCE and prototyping one just to illustrate the point of the post is a bit too much for me... So I will not discuss it further. However the advice here would be: *use and preferably check results of the computations inside your microbenchmarks to prevent DCE from throwing them away*. Checking is especially helpful because it allows to catch bugs both in microbenchmarks and JIT compilers.

What did we actually measure?
-----------------------------

Now that we understood why Sphinx ate us and got some tips on avoiding it in the future it is time to dig a little bit deeper.

Is there any difference between optimized code produced for the loop inside `CostOfLoop` and the loop inside `CostOfLengthPlusLoop`? Were we actually right when we said that `CostOfLengthPlusLoop` is $(C_{op} + C_{loop})$?

Looking at the generated code indeed reveals that there is a difference:

{% highlight nasm %}
;; CostOfLoop loop

B5: ;; LOOP entry
mov [ebp-0x3c], eax
;; cmp-id-and-branch
cmp eax, ebx
jnl B6
;; stack-check
cmp esp, [0xba5adc]
jc StackGuard
;; add-i
add eax, 0x1
;; goto
jmp B5
{% endhighlight %}

{% highlight nasm %}
;; CostOfLenthPlusLoop loop

B5: ;; LOOP entry
mov [ebp-0x40], ecx  ;; (1)
mov [ebp-0x3c], eax
;; cmp-id-and-branch.
cmp eax, edi
jnl B6
;; stack-check
cmp esp,[0xba5adc]
jc StackGuard
;; add-i
add eax, 0x1
mov ecx, ebx ;; (2)
;; goto
jmp B5
{% endhighlight %}

<small>[Confusing <code>stack-check</code> inside both loops is emitted by V8 to allow interruption of long running loops. If V8 for some reason (debugging, preemption, GC request etc) needs to pause JavaScript execution it will just set stack limit (located at `0xba5adc` for the runs above) and any currently running loop will pass control to the runtime system.]</small>

Indeed two strange moves appeared in `CostOfLenthPlusLoop`. My math was wrong again!

$$C_{loop'} = C_{loop} + N(C_{(1)} + C_{(2)})$$

The second one `(2)` is easy to explain: it came from the &phi;-function for the variable `res`. This variable is `0` (if loop was not executed) and is equal to `str.length` after the first iteration. That's exactly what this move does - initializes `res` at the backedge of the loop.

<small>[Attentive readers with a bit of compiler background could have noticed that if the loop was peeled then this move would disappear because `res` never changes after the first iteration.]</small>

Now, where did `(1)` come from? It stores `res` into a memory location (stack slot) that is never read again inside the loop. This does not make much sense! Indeed it does not, but it's actually a long story. It's an artifact of the simple approach that V8 uses in its register allocator to place spill stores: if the value is spill somewhere during its lifetime then it is spilled at its definition.

In our case `res` is spilled to the stack after the loop because we have a call to `Date.now`. This causes both `res` and `i` to be stored to their spill slots again and again on loop entry. It is surely suboptimal and can be fixed (see [Issue 2450](https://code.google.com/p/v8/issues/detail?id=2450) for more details).

Essentially those spill stores and `stack-check` (that involves memory load) is what consumes most cycles when you time both loops. Even if `str.length` was still inside the loop its cost would be quite negligible compared to the cost of the loop itself.

In any case right now overall difference between `CostOfLenthPlusLoop` and `CostOfLoop` is far too small for millisecond precision measurement even with `N = 1e9`.

Moral?
------

*...and &#956;benchmarks, Sphinx, compiler engineer and our hero lived happily ever after*

I think the only way to win this game against the merciless Sphinx is to transcend the question and realize that there is no single right and simple answer to it.

The time when you could have easily guessed the cost of a single operation by simple observation is over. If you want to know something then sometimes the only way is to go and actually learn it from the inside out.

Take care and don't fall into the Sphinx's fairy tale trap again.

<script type="text/x-mathjax-config">
  MathJax.Hub.Config({
    tex2jax: {
      inlineMath: [['$','$'], ['\\(','\\)']],
      skipTags: ["script","noscript","style","textarea"]
    }
  });
</script>
<script type="text/javascript"
  src="https://c328740.ssl.cf1.rackcdn.com/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML">
</script>
