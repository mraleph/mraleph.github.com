---
layout: blogpost
title: 'Microbenchmarks are experiments'
date: 2024-11-27
---

Wake up babe, new microbenchmark just dropped!

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">More languages, more insights!<br><br>A few interesting takeaways:<br><br>* Java and Kotlin are quick! Possible explanation: Google is heavily invested in performance here.<br>* Js is really fast as far as interpreted / jit languages go.<br>* Python is quite slow without things like PyPy. <a href="https://t.co/GIshus2UXO">pic.twitter.com/GIshus2UXO</a></p>&mdash; Ben Dicken (@BenjDicken) <a href="https://twitter.com/BenjDicken/status/1861072804239847914?ref_src=twsrc%5Etfw">November 25, 2024</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

This one has cool animations of balls bouncing around. It claims _more
insights_ compared to the other microbenchmark that was all the rage last
week! Yay!

Sigh. 2025 is almost around the corner and people still seem to think that the
goal of a benchmark is to produce a number which by itself reveals some hidden
truth about the world. You write a loop in Dart, you write a loop in C. You
run it three times (_statistics_!). You compare the running time and,
lo and behold, these two numbers reveal you all you need to know about
Dart and C performance. The rest of the day can be spent browsing numerological
magazines for the meaning of your date of birth...

<p class="sidenote-host">Benchmarks are not numerology. Their results are not a divine revelation.
Benchmarks are <em>experiments</em>. Their results are meaningless without
interpretation and validation. Our understanding of performance is
driven by the same cyclic process that drives science in general:
you formulate a hypothesis, you devise the experiment, you analyze the results,
you adjust the hypothesis and repeat.<small class="sidenote"><a href="https://en.wikipedia.org/wiki/Zen_and_the_Art_of_Motorcycle_Maintenance">"Zen and The Art of Motorcycle Maintenance"</a> has a pretty good <a href="https://kkh.ltrr.arizona.edu/kkh/natsgc/PDFs-2013/Robert-Pirsig-On-Scientific-Method.pdf" target="_blank">description of scientific method</a>, which I think every programmer should read and will likely benefit from.</small></p>

I hope next time you see a cool benchmark animation on your favorite social
network your first question will rather be _"Why have the author spent time
making the animation, instead of making an analysis of results benchmarks?"_.
The answer is that animations are simpler.

Anyway, the [benchmark in question](https://github.com/bddicken/languages/blob/main/loops/dart/code.dart).
I know, I know. I claimed with rightful indignation that I would not be bothered
by meaningless benchmarks. Still I could not resist trying to _understand_ what
hides behind the number, because that is much more important then the number
itself. The benchmark itself fits on a napkin:

```dart
import 'dart:math';

void main(List<String> args) {
  final u = int.parse(args[0]); // Get an input number from the command line
  final r = Random().nextInt(10000); // Get a random integer 0 <= r < 10k

  final List<int> a = List.filled(10000, 0, growable: false);
  for (int i = 0; i < 10000; i++) {
    // 10k outer loop iterations
    for (int j = 0; j < 100000; j++) {
      // 100k inner loop iterations, per outer loop iteration
      a[i] = a[i] + j % u; // Simple sum
    }
    a[i] += r; // Add a random value to each element in array
  }
  print(a[r]); // Print out a single element from the array
}
```

<p class="sidenote-host">JavaScript version is:
<small class="sidenote">The code is slightly modified compared to the original to make it directly runnable in JavaScriptCore shell: <code>console.log</code> became <code>print</code> and <code>process.argv[2]</code> became <code>arguments[0]</code></small></p>

```js
var u = Number(arguments[0]);           // Get an input number from the command line
var r = Math.floor(Math.random() * 10000); // Get a random number 0 <= r < 10k
var a = new Int32Array(10000);             // Array of 10k elements initialized to 0
for (let i = 0; i < 10000; i++) {          // 10k outer loop iterations
  for (let j = 0; j < 100000; j++) {       // 100k inner loop iterations, per outer loop iteration
    a[i] = a[i] + j%u;                     // Simple sum
  }
  a[i] += r;                               // Add a random value to each element in array
}
print(a[r]);                         // Print out a single element from the array
```

<p class="sidenote-host">Running this on nightly versions of Dart and JavaScriptCore yields the
following:<small class="sidenote">You might be surprised that a former V8 engineer
like me is using JSC for benchmarking here, but that's simply because JSC was
fastest of two runtimes. Thus it makes sense to look at what it does.</small></p>

```console
$ dart compile exe -o dart/code.exe dart/code.dart
Generated: /Users/vegorov/src/temp/languages/loops/dart/code.exe
$ hyperfine '~/.jsvu/bin/javascriptcore js/code.js -- 40' 'dart/code.exe 40'
Benchmark 1: ~/.jsvu/bin/javascriptcore js/code.js -- 40
  Time (mean ± σ):      2.079 s ±  0.026 s    [User: 2.052 s, System: 0.013 s]
  Range (min … max):    2.057 s …  2.145 s    10 runs

Benchmark 2: dart/code.exe 40
  Time (mean ± σ):      2.809 s ±  0.023 s    [User: 2.773 s, System: 0.011 s]
  Range (min … max):    2.790 s …  2.860 s    10 runs

Summary
  ~/.jsvu/bin/javascriptcore js/code.js -- 40 ran
    1.35 ± 0.02 times faster than dart/code.exe 40
```

Okay, that's interesting. Maybe even disconcerting to some. JavaScript is faster
than Dart?! How is this possible? Well, the truth is JavaScript is a pretty
fast language if all you need to is loop over `Int32Array` using constant
iteration bounds and add few integers together.

Leaving snark aside, the first thing to notice is that Dart and JavaScript
programs are not exactly equivalent: JavaScript is written using `Int32Array`
while Dart is using `List<int>` which is closer to JS `Array`. Lets fix that:

```dart
  // ...
  final a = Int64List(10000);
  // ...
```

```console
$ dart compile exe -o dart/code.exe dart/code.dart
Generated: /Users/vegorov/src/temp/languages/loops/dart/code.exe
$ hyperfine '~/.jsvu/bin/javascriptcore js/code.js -- 40' 'dart/code.exe 40'
Benchmark 1: ~/.jsvu/bin/javascriptcore js/code.js -- 40
  Time (mean ± σ):      2.081 s ±  0.033 s    [User: 2.051 s, System: 0.014 s]
  Range (min … max):    2.060 s …  2.171 s    10 runs

Benchmark 2: dart/code.exe 40
  Time (mean ± σ):      2.212 s ±  0.015 s    [User: 2.175 s, System: 0.011 s]
  Range (min … max):    2.192 s …  2.241 s    10 runs

Summary
  ~/.jsvu/bin/javascriptcore js/code.js -- 40 ran
    1.06 ± 0.02 times faster than dart/code.exe 40
```

Well, that's better. Still some difference though, so it makes sense to look
at the generated code.

```console
$ dart compile exe -o dart/code.exe                                   \
  -v                                                                  \
  --extra-gen-snapshot-options=--print-flow-graph-optimized           \
  --extra-gen-snapshot-options=--print-flow-graph-filter=dart_::_main \
  --extra-gen-snapshot-options=--disassemble-optimized                \
  --extra-gen-snapshot-options=--code-comments                        \
  dart/code.dart > /tmp/dart-code.asm 2>&1
$ ~/.jsvu/bin/javascriptcore --dumpDFGDisassembly=true js/code.js -- 40
```

Here is what Dart's AOT compiler produces for the innermost loop:

```armasm
;; B7
;; CheckStackOverflow:58(stack=0, loop=2)
loop:
  ldr tmp, [thr, #56]
  cmp sp, tmp
  bls ->interrupt
;; Branch if RelationalOp(<, v15, v66) goto (5, 6)
  movz tmp2, #0x86a0
  movk tmp2, #0x1 lsl 16
  cmp r4, tmp2
  bge ->loop_exit
;; B5
;; v67 <- LoadIndexed:44([_Int64List] v46, v10)
  add tmp, r2, r1 lsl #3
  ldr r5, [tmp, #23]
;; v23 <- BinaryInt64Op(%, v15, v5)
  cbz r0, 0x1036b2400
  sdiv r7, r4, r0
  msub r6, r7, r0, r4
  cmp r6, zr
  blt ->mod_slow_path
;; v24 <- BinaryInt64Op(+, v67, v23)
  add r7, r5, r6
;; StoreIndexed:50([_Int64List] v46, v10, v24)
  add r5, r2, r1 lsl #3
  str r7, [r5, #23]
;; v25 <- BinaryInt64Op(+, v15, v68 T{_Smi})
  add r5, r4, #0x1
;; ParallelMove r4 <- r5 goto:56 B7
  mov r4, r5
  b ->loop
```

<p class="sidenote-host">JavaScriptCore does this for comparison:<small class="sidenote">I have stripped information about DFG/B3/Air IL levels because it makes output too verbose for an unprepared eye. Full output for both Dart and JSC is available <a href="https://gist.github.com/mraleph/f0b7addc93b81b598c1b97088c9b1f14" target="_blank">here</a></small></p>

```armasm
loop:
  ldr      w7, [x2, w9, uxtw#2]
  sxtw     x6, w8
  mul      x6, x6, x0
  lsr      x6, x6, #32
  asr      w6, w6, #4
  add      w6, w6, w6, lsr #31
  msub     w6, w6, w4, w8
  tst      w8, w8
  b.mi     ->mod_slow_path
  adds     w6, w6, w7
  b.vs     ->overflow
  str      w6, [x2, w9, uxtw#2]
  add      w8, w8, #1
  cmp      w8, w3
  b.lt     ->loop
```

Comparing Dart and JSC output reveals the following differences:

- Modulo operation is nowhere to be seen in JSC output, instead we have
multiplication and some bitwise arithmetic. This is possible because JSC
specialized the code a particular value of `u`. You can notice this in the
DFG dump:
    ```
    4  0 58:  D@139:< 2:->	JSConstant(..., Int32: 40, ...)
    ...
    25  5 58:  D@136:<!2:->	ArithMod(Int32:D@142, Int32:D@139, ...)
    ```
  Modulo with constant divisor can be strength reduced to avoid actual division
  operation.
- JSC has rotate loop in such a way that there is only a single branch
- There is an *interrupt checking* in Dart's code (performed by a confusingly
  named `CheckStackOverflow` IL instruction) and not in JSC code. These
  interrupt checks are inserted to allow VM to interrupt long running code
  to perform various activities (e.g. OOB message delivery or GC).

<p class="sidenote-host">The last item is the most interesting to me. I have always known that the cost
of interrupt checks inserted into all loops tends to add up if these loops are
very tight. I periodically come back to this and discuss with my colleagues
various possible optimizations we could apply here, but so far we have not
come up with something that would be fairly simple to implement and would
significantly improve the performance. Instead, I have added an escape hatch:
<code>@pragma('vm:unsafe:no-interrupts')</code> can tell the compiler that it should
omit interrupt checks on the loops inside the function.
<small class="sidenote">JSC uses a combination of signals and code patching to
interrupt JIT compiled code: a signal is sent to interrupt the thread, if thread
is executing JIT compiled code that code will be patched to go into runtime
system when signal handler completes. See <a href="https://github.com/WebKit/WebKit/blob/d4f357221ebcba32b6c44fe274654c3c387ec810/Source/JavaScriptCore/runtime/VMTraps.cpp" target="_blank"><code>VMTraps.cpp</code></a> and <a href="https://github.com/WebKit/WebKit/blob/d4f357221ebcba32b6c44fe274654c3c387ec810/Source/JavaScriptCore/dfg/DFGJumpReplacement.cpp#L44" target="_blank"><code>JumpReplacement::installVMTrapBreakpoint</code></a>.
For environments where code patching is not an option JSC also supports a
<em>polling based</em>
interruption mechanism which works by inserting explicit checks into the JIT
compiled code.</small>
</p>

It might be tempting to just plaster this pragma on the <code>main</code>, but that's
exactly what one should <em>not</em> do. At least not when using this pragma in the
real world (though you probably should <em>not</em> actually use it in the real world).

```dart
// no. NO. NO! Not a good idea.
// @pragma('vm:unsafe:no-interrupts')
void main(List<String> args) {
  // ...
}
```

<p class="sidenote-host"><small class="sidenote">Other Dart VM specific pragmas are documented <a href="https://github.com/dart-lang/sdk/blob/main/runtime/docs/pragmas.md" target="_blank">here</a>. Those with <code>unsafe</code> in their names are intended to be used with
caution - only if you fully understand the <em>implications</em> associated with them.</small></p>

Your reasoning should go like this: `main` has two nested loops, and executes
for ~2seconds. Making it uninterruptible for the whole two seconds is not a
good idea. What if VM needs to trigger a GC in some other isolate in the same
isolate group? _That GC would have to wait whole 2 seconds, blocking the
whole isolate group._ Not a good idea. Instead, you could do the following:

```dart
void main(List<String> args) {
  // ...
  @pragma('vm:unsafe:no-interrupts')
  void innerLoop(int i) {
    for (int j = 0; j < 100000; j++) {
      // 100k inner loop iterations, per outer loop iteration
      a[i] = a[i] + j % u; // Simple sum
    }
  }

  for (int i = 0; i < 10000; i++) {
    // 10k outer loop iterations
    innerLoop(i);
    a[i] += r; // Add a random value to each element in array
  }
  // ...
}
```

<p class="sidenote-host">This way <code>main</code> will still be interruptible in the outer loop, but there will
be no interrupt checks in the inner loop reducing uninterruptible periods to
0.2ms, which is probably just fine for most of the situations.<small class="sidenote">Note that inliner fully inlines and eliminates overhead of the <code>innerLoop</code>. It does not always happen - so when writing performance sensitive code and factoring it into various helpers you should always check the code which gets generated.</small></p>

This version of Dart code yields the following result:

```console
$ hyperfine '~/.jsvu/bin/javascriptcore js/code.js -- 40' 'dart/code.exe 40'
Benchmark 1: ~/.jsvu/bin/javascriptcore js/code.js -- 40
  Time (mean ± σ):      2.100 s ±  0.059 s    [User: 2.056 s, System: 0.016 s]
  Range (min … max):    2.059 s …  2.236 s    10 runs

Benchmark 2: dart/code.exe 40
  Time (mean ± σ):      2.091 s ±  0.022 s    [User: 2.056 s, System: 0.010 s]
  Range (min … max):    2.069 s …  2.131 s    10 runs

Summary
  dart/code.exe 40 ran
    1.00 ± 0.03 times faster than ~/.jsvu/bin/javascriptcore js/code.js -- 40
```

Which is fine by me. By the way, as described in a sidenote above JSC does also
support polling based interruption, so we could do this comparison the other
way around: keep Dart VM's interruption checks in the code and ask JSC to add
them as well by passing `--usePollingTraps=true`:

```console
$ hyperfine '~/.jsvu/bin/javascriptcore --usePollingTraps=true js/code.js -- 40' 'dart/code.exe 40'
Benchmark 1: ~/.jsvu/bin/javascriptcore --usePollingTraps=true js/code.js -- 40
  Time (mean ± σ):      2.204 s ±  0.032 s    [User: 2.161 s, System: 0.015 s]
  Range (min … max):    2.174 s …  2.261 s    10 runs

Benchmark 2: dart/code.exe 40
  Time (mean ± σ):      2.197 s ±  0.013 s    [User: 2.167 s, System: 0.008 s]
  Range (min … max):    2.187 s …  2.220 s    10 runs

Summary
  dart/code.exe 40 ran
    1.00 ± 0.02 times faster than ~/.jsvu/bin/javascriptcore --usePollingTraps=true js/code.js -- 40
```

Now you ask a question: why are we comparing against JavaScript and
not against a more serious competitor like C?

```cpp
#include "stdio.h"
#include "stdlib.h"
#include "stdint.h"

int main (int argc, char** argv) {
  int u = atoi(argv[1]);               // Get an input number from the command line
  int r = rand() % 10000;              // Get a random integer 0 <= r < 10k
  int32_t a[10000] = {0};              // Array of 10k elements initialized to 0
  for (int i = 0; i < 10000; i++) {    // 10k outer loop iterations
    for (int j = 0; j < 100000; j++) { // 100k inner loop iterations, per outer loop iteration
      a[i] = a[i] + j%u;               // Simple sum
    }
    a[i] += r;                         // Add a random value to each element in array
  }
  printf("%d\n", a[r]);                // Print out a single element from the array
}
```

```console
$ clang -O3 -o c/code.exe c/code.c
$ hyperfine 'c/code.exe 40' 'dart/code.exe 40'
Benchmark 1: c/code.exe 40
  Time (mean ± σ):     644.0 ms ±  11.9 ms    [User: 630.9 ms, System: 3.3 ms]
  Range (min … max):   635.1 ms … 671.6 ms    10 runs

Benchmark 2: dart/code.exe 40
  Time (mean ± σ):      2.234 s ±  0.024 s    [User: 2.186 s, System: 0.014 s]
  Range (min … max):    2.189 s …  2.267 s    10 runs

Summary
  c/code.exe 40 ran
    3.47 ± 0.07 times faster than dart/code.exe 40
```

Well, that's some serious competion!

What if I told you that you can make original Dart version (one with
`List.filled` and interrupt checks) to run just 10% slower than C version with
a _one line change_? And on that line there would be only 4 non-whitespace
characters and a semicolon?

```console
$ hyperfine --warmup 1 'c/code.exe 40' 'dart/code.exe 40'
Benchmark 1: c/code.exe 40
  Time (mean ± σ):     638.6 ms ±   7.0 ms    [User: 629.2 ms, System: 2.1 ms]
  Range (min … max):   631.6 ms … 655.6 ms    10 runs

Benchmark 2: dart/code.exe 40
  Time (mean ± σ):     692.4 ms ±   5.0 ms    [User: 667.6 ms, System: 6.0 ms]
  Range (min … max):   686.1 ms … 701.3 ms    10 runs

Summary
  c/code.exe 40 ran
    1.08 ± 0.01 times faster than dart/code.exe 40
```

Are you ready?

```dart
import 'dart:math';

void main(List<String> args) {
  final u = int.parse(args[0]); // Get an input number from the command line
  final r = Random().nextInt(10000); // Get a random integer 0 <= r < 10k

  final a = List.filled(10000, 0, growable: false);
  for (int i = 0; i < 10000; i++) {
    // 10k outer loop iterations
    a[i]; /* <- THIS LINE WAS ADDED */
    for (int j = 0; j < 100000; j++) {
      // 100k inner loop iterations, per outer loop iteration
      a[i] = a[i] + j % u; // Simple sum
    }
    a[i] += r; // Add a random value to each element in array
  }

  print(a[r]); // Print out a single element from the array
}
```

I added `a[i];` right before the inner loop and that somehow made things
massively faster. How did that happen?

<p class="sidenote-host">What LLVM notices and what Dart does <em>not</em> is that a loop:
<small class="sidenote">As far as I could see by inspecting output of
<code>-mllvm --print-before-all</code> this happens in the LLVM's LICM pass, probably in <a href="https://github.com/llvm/llvm-project/blob/53326ee0cf45fce3f80e2e98638dd27edb20c516/llvm/lib/Transforms/Scalar/LICM.cpp#L1964-L1969" target="_blank"><code>promoteLoopAccessesToScalars</code></a>.</small>
</p>

```dart
for (int j = 0; j < 100000; j++) {
  a[i] = a[i] + j % u; // Simple sum
}
```

is the same as

```dart
var v = a[i];
for (int j = 0; j < 100000; j++) {
  v = v + j % u; // Simple sum
}
a[i] = v;
```

This means inner loop no longer touches any memory which makes it much faster.

<p class="sidenote-host">Dart compiler is <em>relatively</em> good at forwarding loads, but it does not perform
any load hoisting. Once we manually added <code>a[i]</code> before the loop
made <code>a[i]</code> inside the loop redundant. Compiler noticed that it has <code>a[i]</code>
value flowing on all edges and eliminated <code>a[i]</code> load inside the loop:<small class="sidenote">You might be tempted to try combining <code>Int64List</code> change with <code>a[i];</code> hint but that would not work. It turns out that Dart's load forwarding pass is very shy around forwarding stores into typed lists. It is a bug I intend to fix.</small></p>

```dart
var v = a[i];
for (int j = 0; j < 100000; j++) {
 v = v + j % u;
 a[i] = v;  // (1)
}
a[i] = v + r; // (2)
```

After that it noticed that `a[i] = ...` at `(1)` is _dead_ because it will
be overwritten by store at `(2)` and we end up with code similar to the one
LLVM was able to produce.

```dart
var v = a[i];
for (int j = 0; j < 100000; j++) {
 v = v + j % u;
}
a[i] = v + r;
```

In reality compiler should really try to perform this optimization itself:
I have occasionally encountered hot loops (e.g. lexer keeping a
character position in a field) where it would be really beneficial. I am
planning to take a look at this some time in the future.

I wish to conclude this post in a circular fashion, like a novel where
weary hero returns home and discovers that everything, including him, have
changed. Hopefully you, reader, too have changed and no longer believe that
measuring a time it takes to perform 1000000000 of modulo operations and
looking at that number alone somehow enlightens you about performance of
some programming language.