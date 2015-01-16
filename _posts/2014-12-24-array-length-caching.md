---
layout: blogpost
title: How the Grinch stole array.length access
date: 2014-12-24
stylesheets: ['https://cdnjs.cloudflare.com/ajax/libs/prettify/r298/prettify.min.css']
---

My favorite way to bootstrap a Christmas dinner conversation is asking people whether they cache array `length` accesses before their loops or not.

Anybody preferring functional `Array.prototype` iteration methods to rusty old-school `for(;;)`-loops gets an additional piece of cake.

Anybody choosing <code>for(let x of y)</code> will find a neatly wrapped ES6-to-ES5-compiler under their Christmas tree.

But the people who cache... But the people who cache tentatively end up on the naughty list. Ho ho ho.

Ok, don't misunderstand my festive mood. I am not really against the Caching. Caching is one of the most fundamental programming techniques. What makes V8 engine fast? Inline _caching_.

There is in fact a multitude of valid reasons for wanting to cache a certain property access before the loop:

* property is implemented as a getter that asks the user for input via accursed `showModalDialog`;
* property changes in the loop and you need to keep an old value;
* property does not change in the loop and your style guide suggests manually hoisting such properties to aid code comprehension;
* you are running your code on a slow JS interpreter on a ZX80 computer emulated inside one of your browser tabs in JavaScript;
* <span style="color:#C00; font-weight: bold;">profiling and extensive code analysis showed that caching improves the quality of the code.</span>

If _these_ are the reasons my Christmas dinner companions cache `length` before their loops - they are stricken off the naughty list and `push`ed into the nice one instead.

Sometimes however this does not happen. Sometimes people try to defend their choice with jsPerf microbenchmarks.

{% highlight javascript %}
function uncached(arr) {
  for (var i = 0; i < arr.length; i++) {
  }
}

function cached(arr) {
  for (var i = 0, len = arr.length; i < len; i++) {
  }
}

var arr = [];
for (var i = 0; i < 1e4; i++) arr.push(i);
{% endhighlight %}

<small>[I am skipping full and proper `benchmark.js` setup because I <em>am</em> Grinch]</small>

Here the reasoning usually goes as following:

<p>
<div>&mdash; First loop accesses <code>.length</code> on every iteration and as a result we access the property in total <code>(arr.length + 1)</code>-times. Second loop accesses it <code>1</code> time. Obviously better. Look at the jsPerf bars.</div>
<div>&mdash; Why do you think <code>arr.length</code> is accessed every time? - asks Grinch eerily smiling.</div>
<div>&mdash; Well... I have written it this way. Didn't I?</div>
</p>

The Grinch obviously did not ask his question for no reason. Last Christmas he stole himself some <a href="http://mrale.ph/irhydra/2/">IRHydra<sup>2</sup></a>, so he can check what kind of code V8 would generate from these loops.

<p class="sidenote-host"><small class="sidenote">This is high-level intermediate representation (IR) used by V8's optimizing compilation pipeline - Crankshaft. Internally it is known as <em>hydrogen</em>. There is no detailed documentation for individual instructions but most of them have self-explanatory mnemonics. It is <a href="http://en.wikipedia.org/wiki/Static_single_assignment_form">SSA</a> based.</small>Nothing is surprising in the <code>cached</code> version. Everything we expect to be there <b>is</b> there.</p>

<pre class="hydrogen">
t3  Parameter 1  // var arr
s11 Constant 0
s39 Constant 1
## for (var i = 0, len = arr.length; i < len; i++) {
##                       ---^------
s16 LoadNamedField t3.%length@12
    Goto B2 Tagged

!1
B2
s21 Phi [ s11  s40 ]  // var i
    ## for (var i = 0, len = arr.length; i < len; i++) {
    ##                                   --^----
    CompareNumericAndBranch LT s21 s16 goto (B3, B5)

B3
  // Loop body would normally be here, but alas it is empty.
  Goto B4

B4
## for (var i = 0, len = arr.length; i < len; i++) {
##                                            ^--
s40 Add s21 s39
    Goto B2
</pre>

But what happened to <code>uncached</code> version?

<pre class="hydrogen">
t3  Parameter 1  // var arr
s11 Constant 0
s36 Constant 1
## for (var i = 0; i < arr.length; i++) {
##                     ---^------
s24 LoadNamedField t3.%length@12
    Goto B2 Tagged

!1
B2
s16 Phi [ s11  s37 ]  // var i
    ## for (var i = 0; i < arr.length; i++) {
    ##                 --^-----------
    CompareNumericAndBranch LT s16 s24 goto (B3, B5)

B3
  // Loop body would normally be here, but alas it is empty.
  Goto B4

B4
## for (var i = 0; i < arr.length; i++) {
##                                 ^--
s37 Add s16 s36
    Goto B2
</pre>

Somebody stole our <code>arr.length</code> access from inside the loop and unceremoniously placed it outside of the loop. This somebody is V8's optimizing compiler, the true Grinch of this story. Grinch that steals all the easy fun from the microbenchmarking and forces you to *learn* how virtual machines operate.

<small>[Learning VMs is arguably not that bad of kind of fun, so we should even forgive it for not eliminating the do-nothing loop altogether (even though I'm personally looking forward for a day when it will do this)]</small>.

If you feel a grudge against the compiler, you might try to put various stuff into the loop in an attempt to make it fail the *Loop Invariant Code Motion* optimization.

To save you time, something like the code below is not obscure enough to confuse our Grinch-compiler:

{% highlight javascript %}
function uncached(arr) {
  for (var i = 0; i < arr.length; i++) {
    arr[i]
  }
}
{% endhighlight %}

What we need instead is a *call*. Calls are compiler's natural enemies, because that's where *intraprocedural* analyses fail and a need in *interprocedural* analyses arises. Compilers partially mitigate this issue by inlining small functions - thus we also need an *uninlinable* call to really make compiler regret stealing our <s>Christmas</s> `arr.length`.

{% highlight javascript %}
function BLACKHOLE(sum, arr) {
  try { } catch (e) { }
}

function uncached(arr) {
  var sum = 0;
  for (var i = 0; i < arr.length; i++) {
    sum += arr[i];
    if (sum < 0) BLACKHOLE(arr, sum);
  }
  return sum;
}

var narr = [];
for (var i = 0; i < 1e4; i++) narr.push(-i);

// PREPARE: make it look like sum can be negative
var r = uncached(narr);
verify(r);

// BENCHMARK: arr contains only positive integers
// so we are not paying for BLACKHOLE call.
var r = uncached(arr);
verify(r);
{% endhighlight %}

<small>[I am skipping full and proper `benchmark.js` setup again]</small>

`PREPARE` step is actually not needed, but V8 has a tendency to throw away blocks that were never executed if they happen to contain unitialized ICs so I am just guarding against that. In general when benchmarking something it is better to optimistically assume that compiler does a _stellar_ job utilizing profiling information and no worse job discovering dead code. Otherwise compiler might come, passingly stub you in the back and throw away half of your benchmark.

<pre class="hydrogen">
t3  Parameter 1  // var arr
s11 Constant 0
s71 Constant 1

!1
B2
s18 Phi [ s11  s46 ]  // var sum
s19 Phi [ s11  s75 ]  // var i
##  for (var i = 0; i < arr.length; i++) {
##                      ---^------
    CheckMaps t3 [0x5cf0c631]  // check if hidden class changed &#9312;
s27 LoadNamedField t3.%length@12
##  for (var i = 0; i < arr.length; i++) {
##                   -^-
    CompareNumericAndBranch LT s19 s27 goto (B4, B10)

B4
##    sum += arr[i];
##           ---^--
t42 LoadNamedField t3.%elements@8
    BoundsCheck s19 s27  // check if we are reading within bounds &#9313;
s45 LoadKeyed t42[s19] t3
##    sum += arr[i];
##       -^-
s46 Add s18 s45
##    if (sum < 0) BLACKHOLE(arr, sum);
##        ----^--
    CompareNumericAndBranch LT s46 s11 goto (B8, B9)

B8
##    if (sum < 0) BLACKHOLE(arr, sum);
##                 ---------^---------
t85 Change s46 s to t
    PushArguments t62 t3 t85
    CallJSFunction t59 #3 changes[*] // this call changes EVERYTHING!
    Goto B9

B9
##  for (var i = 0; i < arr.length; i++) {
##                                  ^--
s75 Add s19 s74
    Goto B2
</pre>

It seems our attempt to confuse V8's optimizing compiler was a huge success: it can no longer even guarantee that array's _hidden class_ stays the same during iteration so it has to check <code>&#9312;</code> it every time. Likewise as we desired - the length is reloaded every time too.

<small>[Attentive reader can notice here that something is not working properly in V8's bounds check elimination pass. Somehow it fails to eliminate an obviously redundant check <code>&#9313;</code>.]</small>

Hooray! Now the scene has been set for the triumph of the `cached` version!

<pre class="hydrogen">
t3  Parameter 1  // var arr
s11 Constant 0
s77 Constant 1
s18 LoadNamedField t3.%length@12  // var len <code>&#9314;</code>
    Goto B2

!1
B2
s23 Phi [ s11  s49 ]  // var sum
s24 Phi [ s11  s78 ]  // var i
##  for (var i = 0, len = arr.length; i < len; i++) {
##                                    --^----
    CompareNumericAndBranch LT s24 s18 goto (B4, B10)

B4
##    sum += arr[i];
##           ---^--
    CheckMaps t3 [0x28a0c631]
t45 LoadNamedField t3.%elements@8
s46 LoadNamedField t3.%length@12  // <code>&#9315;</code>
    BoundsCheck s24 s46
s48 LoadKeyed t45[s24] t3
##    sum += arr[i];
##       -^--
s49 Add s23 s48 !
##    if (sum < 0) BLACKHOLE(arr, sum);
##        ----^--
s54 CompareNumericAndBranch LT s49 s11 goto (B8, B9)

B8
##    if (sum < 0) BLACKHOLE(arr, sum);
##                 ---------^---------
t88 Change s49 s to t
    PushArguments t65 t3 t88
t68 CallJSFunction t62 #3 changes[*]
    Goto B9

B9
##  for (var i = 0, len = arr.length; i < len; i++) {
##                                             ^--
s78 Add s24 s77
    Goto B2
</pre>

Except not. Now we have **two** places where we access `length` inside the function:

* one _outside_ of the loop marked <code>&#9314;</code> is to initialize `len` and use in the loop condition;
* one _inside_ the loop marked <code>&#9315;</code> is needed for the bounds check before the indexed load.

Thing to realize here is simple: if compiler is unable to figure out that `arr.length` does not change within the loop, you can't help it much by manually caching it. When it needs to access array element, compiler anyway *has* to emit a bounds check which requires loading length. Could it use `len` that we cached for it? No. If compiler could figure out that `s46` and `s18` is the same value it would just hoist `s46` out of the loop without our help.

<small>[There is a code optimization available to JIT here that could eliminate the length load: a sophisticated compiler could take this load (and other stuff related to indexed access) and move it to the point after the call because that is the only place where it changes. If calling is infrequent then this could improve the code quality rather drastically.]</small>

Ok. We can't reason about caching `arr.length` as an optimization that improves the code by reducing a number of `arr.length` accesses. How sad! At least we are not making anything worse.

Ho ho ho.

Well, in fact we do make some thing somewhat worse: the life of a poor register allocator. When we manually cache length we give it one more live value to care about and keep around in the loop. Compare these two back edges:

{% highlight nasm %}
;; uncached version
mov edx, [ebp - 0x18] ;; restore sum
mov eax, [ebp + 0x8]  ;; restore arr
jmp ->B2

;; cached version
mov ebx, [ebp - 0x1c] ;; restore sum
mov eax, [ebp + 0x8]  ;; restore arr
mov ecx, [ebp - 0x14] ;; restore len
jmp ->B2
{% endhighlight %}

<p class="sidenote-host"><small class="sidenote">Even though there are enough free registers to keep all values alive in the loop - register allocator still spills them because there is a call to <code>BLACKHOLE</code> in the loop.</small>As you can see in the cached version we end up reloading <code>len</code> again and again on every backedge. Essentially our <b>failed</b> attempt to eliminate a <code>LoadNamedField t3.%length</code>, which itself compiles down to a single <code>mov ebx, [eax + 0xb]</code>, ended up adding one more memory move instead of removing one.</p>

Does this additional move on the back-edge have any performance implications? With our microbenchmark written the way it is this move is probably completely hidden in the shadow of other memory operations on modern desktop CPUs. The story might be different on older CPUs or mobile devices, but I am not sure this a research area we should be digging into here: ultimately the more real work you do in the loop the less our microbenchmark results will matter.

Just for fun I tweaked microbenchmark a bit to increase the pressure:

{% highlight javascript %}
function uncached(arr, x1, x2, x3) {
  var sum = 0;
  for (var i = 0; i < arr.length; i++) {
    sum += x1;
    sum += x2;
    sum += x3;  // lets hope V8 doesn't reassociate expressions :)
    sum += arr[i];
    if (sum < 0) BLACKHOLE(arr, sum);
  }
  return sum;
  /* ------------------------------------------------------ */
  /* ------------------------------------------------------ */
  /* ------------------------------------------------------ */
  /* ---------- __attribute__((never_inline)) ------------- */
  /* ------------------------------------------------------ */
  /* ------------------------------------------------------ */
  /* ------------------------------------------------------ */
}

function cached(arr, x1, x2, x3) {
  /* similar change */
}

new Benchmark.Suite()
  .add('Cached', function () { cached(arr, 0, 0, 0); })
  .add('Uncached', function () { uncached(arr, 0, 0, 0); })
  .on('cycle', function(event) {
    print(String(event.target));
  })
  .on('complete', function() {
    print('Fastest is ' + this.filter('fastest').pluck('name'));
  })
  .on('error', function (e) {
    print("" + e.target.error);
  })
  .run({'async': false});
{% endhighlight %}

Running this on one my boxes yielded the following result:

<pre>
$ out/ia32.release/d8 test.js
Uncached x <span style="color: #C00; font-weight: bold;">26,435</span> ops/sec &pm;2.48% (65 runs sampled)
Cached x 17,922 ops/sec &pm;1.26% (66 runs sampled)
Fastest is Uncached
</pre>

Whoa. Uncache all the things! Except I could not repeat this on any other machines available to me. Does it make sense to base your coding style on a flaky microbenchmark?

Yes, we really are treading on a really thin ice of CPU performance effects with these microbenchmarks. I think the Grinch is going to leave you on your own now.

<span style="color: white; border: 1px #7A0026 solid; padding: 0px 2px; background: #7a0026;">Update 26 December 2014</span>

Every tale has a morale and my story about the Grinch should have one too.

**Understand before acting**

Yes, surprisingly it has nothing to do with caching or not caching `array.length` access. Don't derive your code style from microbenchmarks. Don't base it on advices from esteemed elders (or mine for that matter). Instead invest into understanding where, how and why your application is spending CPU cycles.

There is another morale here: *don't blindly trust microbenchmarks, they are often not measuring what you think they are measuring*.

In my attempt to illustrate this I focused on a single microbenchmark and ignored a lot of other interesting issues:

1. in the beginning of the post I passingly noted that I favor `Array.prototype.*` iteration methods to old-school `for(;;)`-loop. How do I reconcile this with the fact that these methods are still more expensive than a good old `for(;;)`-loop?
2. this post deals only with `Array` objects. What about native DOM objects like `HTMLCollection`? It's a fact that accessing `HTMLCollection.length` is more expensive than `array.length`.
3. this posts talks only about V8. What if I have to target other JavaScript VMs? What if I have to target old browsers?

These are all valid questions and unfortunately I simply can't touch them all in a single post. In some sense mantra _"measure, understand, act, measure"_ is still the best answer to all three even though it might sound disappointingly generic.

Does it matter if you use `.map()` instead of `for(;;)`?

Does it matter if you cache `HTMLCollection.length`?

It depends. Does your application spend considerable time in those methods? Which VMs are you targeting? What's your coding style?

I don't think there is a universal answer to these questions.

<script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/prettify/r298/prettify.min.js">
</script>
<script type="text/javascript" src="/js/ir.js">
</script>

