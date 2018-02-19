---
layout: blogpost
title: Maybe you don't need Rust and WASM to speed up your JS
date: 2018-02-03
---

Few weeks ago I noticed a blog post ["Oxidizing Source Maps with Rust and WebAssembly"](https://hacks.mozilla.org/2018/01/oxidizing-source-maps-with-rust-and-webassembly/)
making rounds on Twitter - talking about performance benefits of replacing
plain JavaScript in the core of `source-map` library with a Rust compiled to
WebAssembly.

This post piqued my interest, not because I am a huge on either Rust or WASM,
but rather because I am always curious about language features and
optimizations missing in pure JavaScript to achieve similar performance
characteristics.

So I checked out the library from GitHub and departed on a small performance
investigation, which I am documenting here almost verbatim.

* TOC
{:toc}

# Getting the Code

For my investigations I was using an *almost* default x64.release build of the V8 at commit [69abb960c97606df99408e6869d66e014aa0fb51](https://chromium.googlesource.com/v8/v8/+/69abb960c97606df99408e6869d66e014aa0fb51) from January 20th.
My only deparature from default configuration is that I enable disassembler via GN flags to
be able to dive down to generated machine code if needed.

```console
╭─ ~/src/v8/v8 ‹master›
╰─$ gn args out.gn/x64.release --list --short --overrides-only
is_debug = false
target_cpu = "x64"
use_goma = true
v8_enable_disassembler = true
```

Then I got a checkouts of [`source-map`](https://github.com/mozilla/source-map) package at:

* [commit c97d38b](https://github.com/mozilla/source-map/commit/c97d38b70de088d87b051f81b95c138a74032a43), which was the last commit that updated `dist/source-map.js` before Rust/WASM started landed;
* [commit 51cf770](https://github.com/mozilla/source-map/commit/51cf7708dd70d067dfe04ce36d546f3262b48da3)
which was the most recent commit, when I did my investigation;

TODO: add note about commit [commit 264fcb4](https://github.com/mozilla/source-map/commit/264fcb4331d75e1b6a41f75fd6c601af61870536) which was the last commit before Rust/WASM stuff landing;

# Profiling the Pure-JavaScript Version

Running benchmark in the pure-JS version was rather simple:

```console
╭─ ~/src/source-map/bench ‹ c97d38b›
╰─$ d8 bench-shell-bindings.js
Parsing source map
console.timeEnd: iteration, 4655.638000
console.timeEnd: iteration, 4751.122000
console.timeEnd: iteration, 4820.566000
console.timeEnd: iteration, 4996.942000
console.timeEnd: iteration, 4644.619000
[Stats samples: 5, total: 23868 ms, mean: 4773.6 ms, stddev: 161.22112144505135 ms]
```

The first thing that I did was to disabled the serialization part of the
benchmark:

```
diff --git a/bench/bench-shell-bindings.js b/bench/bench-shell-bindings.js
index 811df40..c97d38b 100644
--- a/bench/bench-shell-bindings.js
+++ b/bench/bench-shell-bindings.js
@@ -19,5 +19,5 @@ load("./bench.js");
 print("Parsing source map");
 print(benchmarkParseSourceMap());
 print();
-print("Serializing source map");
-print(benchmarkSerializeSourceMap());
+// print("Serializing source map");
+// print(benchmarkSerializeSourceMap());
```

And then threw it into the Linux `perf` profiler:

```console
╭─ ~/src/source-map/bench ‹perf-work›
╰─$ perf record -g d8 --perf-basic-prof bench-shell-bindings.js
Parsing source map
console.timeEnd: iteration, 4984.464000
^C[ perf record: Woken up 90 times to write data ]
[ perf record: Captured and wrote 24.659 MB perf.data (~1077375 samples) ]
```

Notice that I am passing `--perf-basic-prof` flag to the `d8` binary which
instructs V8 to generate an auxiliary mappings file `/tmp/perf-$pid.map`. This
file allows `perf report` to understand JIT generated machine code.

Here is what we get from `perf report --no-children` after zooming on
the main execution thread:

```console
Overhead  Symbol
  17.02%  *doQuickSort ../dist/source-map.js:2752
  11.20%  Builtin:ArgumentsAdaptorTrampoline
   7.17%  *compareByOriginalPositions ../dist/source-map.js:1024
   4.49%  Builtin:CallFunction_ReceiverIsNullOrUndefined
   3.58%  *compareByGeneratedPositionsDeflated ../dist/source-map.js:1063
   2.73%  *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
   2.11%  Builtin:StringEqual
   1.93%  *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
   1.66%  *doQuickSort ../dist/source-map.js:2752
   1.25%  v8::internal::StringTable::LookupStringIfExists_NoAllocate
   1.22%  *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
   1.21%  Builtin:StringCharAt
   1.16%  Builtin:Call_ReceiverIsNullOrUndefined
   1.14%  v8::internal::(anonymous namespace)::StringTableNoAllocateKey::IsMatch
   0.90%  Builtin:StringPrototypeSlice
   0.86%  Builtin:KeyedLoadIC_Megamorphic
   0.82%  v8::internal::(anonymous namespace)::MakeStringThin
   0.80%  v8::internal::(anonymous namespace)::CopyObjectToObjectElements
   0.76%  v8::internal::Scavenger::ScavengeObject
   0.72%  v8::internal::String::VisitFlat<v8::internal::IteratingStringHasher>
   0.68%  *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
   0.64%  *doQuickSort ../dist/source-map.js:2752
   0.56%  v8::internal::IncrementalMarking::RecordWriteSlow
```

Just like original post has stated the benchmark indeed is heavy on sort: `doQuickSort`
appaers at the top of the profile and also few times down the list (most likely
it was optimized several times).

# Optimizing Sorting - Argument Adaptation

There are also some suspicious overheads,
namely `Builtin:ArgumentsAdaptorTrampoline` and `Builtin:CallFunction_ReceiverIsNullOrUndefined`
which seem to be part of V8 implementation. If we ask `perf report` to expand
call chains then we will notice that these functions are also mostly invoked
from the sorting code:

```console
- Builtin:ArgumentsAdaptorTrampoline
  + 96.87% *doQuickSort ../dist/source-map.js:2752
  +  1.22% *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
  +  0.68% *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
  +  0.68% Builtin:InterpreterEntryTrampoline
  +  0.55% *doQuickSort ../dist/source-map.js:2752

- Builtin:CallFunction_ReceiverIsNullOrUndefined
  + 93.88% *doQuickSort ../dist/source-map.js:2752
  +  2.24% *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
  +  2.01% Builtin:InterpreterEntryTrampoline
  +  1.49% *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
```

It is time to look at the code. Quicksort implementation itself lives in [`lib/quite-sort.js`](https://github.com/mozilla/source-map/blob/c97d38b70de088d87b051f81b95c138a74032a43/lib/quick-sort.js) and
it is invoked from parsing code in [`lib/source-map-consumer.js`](https://github.com/mozilla/source-map/blob/c97d38b70de088d87b051f81b95c138a74032a43/lib/source-map-consumer.js#L564-L568). Comparison functions used for sorting are [`compareByGeneratedPositionsDeflated`](https://github.com/mozilla/source-map/blob/c97d38b70de088d87b051f81b95c138a74032a43/lib/util.js#L334-L343) and [`compareByOriginalPositions`](https://github.com/mozilla/source-map/blob/c97d38b70de088d87b051f81b95c138a74032a43/lib/util.js#L296-L304).

Looking at the definition of the comparison function and how they are invoked
from quick sort implementation reveals that the invocation site has mismatching
arity:

```js
function compareByOriginalPositions(mappingA, mappingB, onlyCompareOriginal) {
  // ...
}

function compareByGeneratedPositionsDeflated(mappingA, mappingB, onlyCompareGenerated) {
  // ...
}

function doQuickSort(ary, comparator, p, r) {
  // ...
      if (comparator(ary[j], pivot) <= 0) {
        // ...
      }
  // ...
}
```

Grepping through library sources reveals that outside of tests `quickSort` is
only ever called with these two functions.

What if we fix the invocation arity?

```diff
diff --git a/dist/source-map.js b/dist/source-map.js
index ade5bb2..2d39b28 100644
--- a/dist/source-map.js
+++ b/dist/source-map.js
@@ -2779,7 +2779,7 @@ return /******/ (function(modules) { // webpackBootstrap
            //
            //   * Every element in `ary[i+1 .. j-1]` is greater than the pivot.
            for (var j = p; j < r; j++) {
-             if (comparator(ary[j], pivot) <= 0) {
+             if (comparator(ary[j], pivot, false) <= 0) {
                i += 1;
                swap(ary, i, j);
              }
```

[Note: I am doing edits directly in `dist/source-map.js` because I did not
want to spend time figuring out the build process]

```console
╭─ ~/src/source-map/bench ‹perf-work› [Fix comparator invocation arity]
╰─$ d8 bench-shell-bindings.js
Parsing source map
console.timeEnd: iteration, 4037.084000
console.timeEnd: iteration, 4249.258000
console.timeEnd: iteration, 4241.165000
console.timeEnd: iteration, 3936.664000
console.timeEnd: iteration, 4131.844000
console.timeEnd: iteration, 4140.963000
[Stats samples: 6, total: 24737 ms, mean: 4122.833333333333 ms, stddev: 132.18789657150916 ms]
```

So just by fixing the arity mismatch we improved benchmark mean from 4774 ms
to 4123 ms (by 14%). If we profile the benchmark again we will discover that
`ArgumentsAdaptorTrampoline` has completely disappeared from it. What was that
about?

It turns out that `ArgumentsAdaptorTrampoline` is V8 mechanism for coping with
JavaScript's variadic calling convention: e.g. you can call function that
has 3 parameters with 2 arguments - in which case the third parameter will be
filled with `undefined`. V8 does this by creating a new frame on the stack,
copying arguments down and then invoking the target function:

![Argument adaptation](/images/2018-02-03/argument-adaptation.png)

<small markdown="1">
[If you have never heard about *execution stack*, checkout out [Wikipedia](https://en.wikipedia.org/wiki/Call_stack) and Franziska Hinkelmann [blog post](https://fhinkel.rocks/2017/10/30/Confused-about-Stack-and-Heap/).]
</small>

While such costs might be negligable for cold code, in the sort code `comparator`
was invocated millions of times which made overheads of arguments adaptation
quite pronounced.

An attentive reader would also notice that we are now explicitly passing boolean
value `false` where previously an implicit `undefined` was used. This does
seem to contribute a bit to the performance improvement. If we replace `false`
with `void 0` we would get slightly worse numbers:

```
diff --git a/dist/source-map.js b/dist/source-map.js
index 2d39b28..243b2ef 100644
--- a/dist/source-map.js
+++ b/dist/source-map.js
@@ -2779,7 +2779,7 @@ return /******/ (function(modules) { // webpackBootstrap
            //
            //   * Every element in `ary[i+1 .. j-1]` is greater than the pivot.
            for (var j = p; j < r; j++) {
-             if (comparator(ary[j], pivot, false) <= 0) {
+             if (comparator(ary[j], pivot, void 0) <= 0) {
                i += 1;
                swap(ary, i, j);
              }
```

```console
╭─ ~/src/source-map/bench ‹perf-work U› [Fix comparator invocation arity]
╰─$ ~/src/v8/v8/out.gn/x64.release/d8 bench-shell-bindings.js
Parsing source map
console.timeEnd: iteration, 4215.623000
console.timeEnd: iteration, 4247.643000
console.timeEnd: iteration, 4425.871000
console.timeEnd: iteration, 4167.691000
console.timeEnd: iteration, 4343.613000
console.timeEnd: iteration, 4209.427000
[Stats samples: 6, total: 25610 ms, mean: 4268.333333333333 ms, stddev: 106.38947316346669 ms]
```

For what it is worth argument adapation overhead seems to be highly V8 specific.
When I benchmark my change against SpiderMonkey (which is now easy to install
thanks to Mathias Bynens [jsvu](https://github.com/GoogleChromeLabs/jsvu) tool),
I don't see any significant performance improvement from matching the arity:

```console
╭─ ~/src/source-map/bench ‹ d052ea4› [Disabled serialization part of the benchmark]
╰─$ sm bench-shell-bindings.js
Parsing source map
[Stats samples: 8, total: 24751 ms, mean: 3093.875 ms, stddev: 327.27966571700836 ms]
╭─ ~/src/source-map/bench ‹perf-work› [Fix comparator invocation arity]
╰─$ sm bench-shell-bindings.js
Parsing source map
[Stats samples: 8, total: 25397 ms, mean: 3174.625 ms, stddev: 360.4636187025859 ms]
```

<small>[Also SpiderMonkey seems to be doing the whole thing faster.]</small>

Lets get back to the sorting code. If we profile the benchmark again we will
notice that while `ArgumentsAdaptorTrampoline` is gone for good from the profile
`CallFunction_ReceiverIsNullOrUndefined` is still there. This is not surprising
given that we are still calling the `comparator`.

# Optimizing Sorting - Monomorphisation

What usually performs better than calling the function? The obvious option is
to try to get the comparator inlined into the `doQuickSort`. However the fact
that `doQuickSort` is called with different `comparator` functions stands on
the way of inlining.

To work around this we can try to monomorphise `doQuickSort` by cloning it. Here
is how we do it.

We start by wrapping `doQuickSort` and other helpers into `SortTemplate`
function:

```js
function SortTemplate(comparator) {
  function swap(ary, x, y) {
    // ...
  }

  function randomIntInRange(low, high) {
    // ...
  }

  function doQuickSort(ary, p, r) {
    // ...
  }

  return doQuickSort;
}
```

Then we can produce clones of our sorting routines by converting `SortTemplate`
into a string and then parsing it back into a function via `Function`
constructor:

```js
function cloneSort(comparator) {
  let template = SortTemplate.toString();
  let templateFn = new Function(`return ${template}`)();
  return templateFn(comparator);  // Invoke template to get doQuickSort
}
```

Now we can use `cloneSort` to produce a sort function for each comparator we
are using:

```js
let sortCache = new WeakMap();  // Cache for specialized sorts.
exports.quickSort = function (ary, comparator) {
  let doQuickSort = sortCache.get(comparator);
  if (doQuickSort === void 0) {
    doQuickSort = cloneSort(comparator);
    sortCache.set(comparator, doQuickSort);
  }
  doQuickSort(ary, 0, ary.length - 1);
};
```

Rerunning benchmark yields:

```console
╭─ ~/src/source-map/bench ‹perf-work› [Clone sorting functions for each comparator]
╰─$ d8 bench-shell-bindings.js
Parsing source map
console.timeEnd: iteration, 2955.199000
console.timeEnd: iteration, 3084.979000
console.timeEnd: iteration, 3193.134000
console.timeEnd: iteration, 3480.459000
console.timeEnd: iteration, 3115.011000
console.timeEnd: iteration, 3216.344000
console.timeEnd: iteration, 3343.459000
console.timeEnd: iteration, 3036.211000
[Stats samples: 8, total: 25423 ms, mean: 3177.875 ms, stddev: 181.87633161024556 ms]
```

We can see that the mean time went from 4268 ms to 3177 ms (25% improvent).

Profiling reveals the following picture:

```console
 Overhead Symbol
   14.95% *doQuickSort :44
   11.49% *doQuickSort :44
    3.29% Builtin:StringEqual
    3.13% *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
    1.86% v8::internal::StringTable::LookupStringIfExists_NoAllocate
    1.86% *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
    1.72% Builtin:StringCharAt
    1.67% *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
    1.61% v8::internal::Scavenger::ScavengeObject
    1.45% v8::internal::(anonymous namespace)::StringTableNoAllocateKey::IsMatch
    1.23% Builtin:StringPrototypeSlice
    1.17% v8::internal::(anonymous namespace)::MakeStringThin
    1.08% Builtin:KeyedLoadIC_Megamorphic
    1.05% v8::internal::(anonymous namespace)::CopyObjectToObjectElements
    0.99% v8::internal::String::VisitFlat<v8::internal::IteratingStringHasher>
    0.86% clear_page_c_e
    0.77% v8::internal::IncrementalMarking::RecordWriteSlow
    0.48% Builtin:MathRandom
    0.41% Builtin:RecordWrite
    0.39% Builtin:KeyedLoadIC
```

Stuff related to invoking `comparator` is not completely out of the profile.

At this point I became interested in how much time we spend actually parsing
mappings vs. sorting them. I went into the parsing code and added few
`Date.now()` invocations:

<small markdown="1">[I wanted to sprinkle `performance.now()` but SpiderMonkey
shell apparently does not support it.]</small>

```diff
diff --git a/dist/source-map.js b/dist/source-map.js
index 75ebbdf..7312058 100644
--- a/dist/source-map.js
+++ b/dist/source-map.js
@@ -1906,6 +1906,8 @@ return /******/ (function(modules) { // webpackBootstrap
            var generatedMappings = [];
            var mapping, str, segment, end, value;

+
+      var startParsing = Date.now();
            while (index < length) {
              if (aStr.charAt(index) === ';') {
                generatedLine++;
@@ -1986,12 +1988,20 @@ return /******/ (function(modules) { // webpackBootstrap
                }
              }
            }
+      var endParsing = Date.now();

+      var startSortGenerated = Date.now();
            quickSort(generatedMappings, util.compareByGeneratedPositionsDeflated);
            this.__generatedMappings = generatedMappings;
+      var endSortGenerated = Date.now();

+      var startSortOriginal = Date.now();
            quickSort(originalMappings, util.compareByOriginalPositions);
            this.__originalMappings = originalMappings;
+      var endSortOriginal = Date.now();
+
+      console.log(`${}, ${endSortGenerated - startSortGenerated}, ${endSortOriginal - startSortOriginal}`);
+      console.log(`sortGenerated: `);
+      console.log(`sortOriginal:  `);
          };
```

This yielded:


```console
╭─ ~/src/source-map/bench ‹perf-work U› [Clone sorting functions for each comparator]
╰─$ d8 bench-shell-bindings.js
Parsing source map
parse:         1911.846
sortGenerated: 619.5990000000002
sortOriginal:  905.8220000000001
parse:         1965.4820000000004
sortGenerated: 602.1939999999995
sortOriginal:  896.3589999999995
^C
```

Here is how parsing and sorting times look like in V8 and SpiderMonkey per
benchmark iteration run:

![Parse and Sort times](/images/2018-02-03/parse-sort-0.png)

In V8 we seem to be spending roughly as much time parsing mappings as then
sorting them. In SpiderMonkey parsing is considerably faster - while sorting
is slower. This prompted me to start looking at the parsing code.

# Optimizing Parsing - Removing Segment Cache

Lets take a look at the profile again

```console
Overhead  Symbol
  18.23%  *doQuickSort :44
  12.36%  *doQuickSort :44
   3.84%  *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
   3.07%  Builtin:StringEqual
   1.92%  v8::internal::StringTable::LookupStringIfExists_NoAllocate
   1.85%  *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
   1.59%  *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
   1.54%  Builtin:StringCharAt
   1.52%  v8::internal::(anonymous namespace)::StringTableNoAllocateKey::IsMatch
   1.38%  v8::internal::Scavenger::ScavengeObject
   1.27%  Builtin:KeyedLoadIC_Megamorphic
   1.22%  Builtin:StringPrototypeSlice
   1.10%  v8::internal::(anonymous namespace)::MakeStringThin
   1.05%  v8::internal::(anonymous namespace)::CopyObjectToObjectElements
   1.03%  v8::internal::String::VisitFlat<v8::internal::IteratingStringHasher>
   0.88%  clear_page_c_e
   0.51%  Builtin:MathRandom
   0.48%  Builtin:KeyedLoadIC
   0.46%  v8::internal::IteratingStringHasher::Hash
   0.41%  Builtin:RecordWrite
```

Removing our JavaScript code leaves us with the following:

```console
Overhead  Symbol
   3.07%  Builtin:StringEqual
   1.92%  v8::internal::StringTable::LookupStringIfExists_NoAllocate
   1.54%  Builtin:StringCharAt
   1.52%  v8::internal::(anonymous namespace)::StringTableNoAllocateKey::IsMatch
   1.38%  v8::internal::Scavenger::ScavengeObject
   1.27%  Builtin:KeyedLoadIC_Megamorphic
   1.22%  Builtin:StringPrototypeSlice
   1.10%  v8::internal::(anonymous namespace)::MakeStringThin
   1.05%  v8::internal::(anonymous namespace)::CopyObjectToObjectElements
   1.03%  v8::internal::String::VisitFlat<v8::internal::IteratingStringHasher>
   0.88%  clear_page_c_e
   0.51%  Builtin:MathRandom
   0.48%  Builtin:KeyedLoadIC
   0.46%  v8::internal::IteratingStringHasher::Hash
   0.41%  Builtin:RecordWrite
```

When I started looking at call chains for individual entries I discovered that
many of them go through `KeyedLoadIC_Megamorphic` into
`SourceMapConsumer_parseMappings`.

```console
-    1.92% v8::internal::StringTable::LookupStringIfExists_NoAllocate
   - v8::internal::StringTable::LookupStringIfExists_NoAllocate
      + 99.80% Builtin:KeyedLoadIC_Megamorphic

-    1.52% v8::internal::(anonymous namespace)::StringTableNoAllocateKey::IsMatch
   - v8::internal::(anonymous namespace)::StringTableNoAllocateKey::IsMatch
      - 98.32% v8::internal::StringTable::LookupStringIfExists_NoAllocate
         + Builtin:KeyedLoadIC_Megamorphic
      + 1.68% Builtin:KeyedLoadIC_Megamorphic

-    1.27% Builtin:KeyedLoadIC_Megamorphic
   - Builtin:KeyedLoadIC_Megamorphic
      + 57.65% *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
      + 22.62% *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
      + 15.91% *SourceMapConsumer_parseMappings ../dist/source-map.js:1894
      + 2.46% Builtin:InterpreterEntryTrampoline
      + 0.61% BytecodeHandler:Mul
      + 0.57% *doQuickSort :44

-    1.10% v8::internal::(anonymous namespace)::MakeStringThin
   - v8::internal::(anonymous namespace)::MakeStringThin
      - 94.72% v8::internal::StringTable::LookupStringIfExists_NoAllocate
         + Builtin:KeyedLoadIC_Megamorphic
      + 3.63% Builtin:KeyedLoadIC_Megamorphic
      + 1.66% v8::internal::StringTable::LookupString
```

This sort of call stacks indicated to me that code is performing a lot of keyed
lookups of form `obj[key]` where `key` is dynamically built string. When I
looked at the parsing I discovered [the following code](https://github.com/mozilla/source-map/blob/693728299cf87d1482e4c37ae90f5bce8edf899f/lib/source-map-consumer.js#L496-L529):

```js
// Because each offset is encoded relative to the previous one,
// many segments often have the same encoding. We can exploit this
// fact by caching the parsed variable length fields of each segment,
// allowing us to avoid a second parse if we encounter the same
// segment again.
for (end = index; end < length; end++) {
  if (this._charIsMappingSeparator(aStr, end)) {
    break;
  }
}
str = aStr.slice(index, end);

segment = cachedSegments[str];
if (segment) {
  index += str.length;
} else {
  segment = [];
  while (index < end) {
    base64VLQ.decode(aStr, index, temp);
    value = temp.value;
    index = temp.rest;
    segment.push(value);
  }

  // ...

  cachedSegments[str] = segment;
}
```

This code is responsible for decoding Base64 VLQ encoded sequences, e.g. string
`A` would be decoded as `[0]` and `UAAAA` gets decoded as `[10,0,0,0,0]`. I
suggest checking [this blog post](https://blogs.msdn.microsoft.com/davidni/2016/03/14/source-maps-under-the-hood-vlq-base64-and-yoda/) about
source maps internals if you would like to understand the encoding itself
better.

Instead of decoding each sequence independently, the code attempts to cache
decoded segments: it scans forward until a separator (`,` or `;`) is found,
then extracts substring from the current position to the separator and
checks if we have previous decoded such segment by looking up the extracted
substring in a cache - if we hit the cache we return cached segment, otherwise
we parse and cache the segment in the cache.

Caching (aka memoization) is very powerful optimization technique - however it
only makes sense when maintaining the cache itself and looking up cached
results is cheaper than performing computation itself again.

## Abstract Analysis

Lets try to compare these two operations abstractly.

**On one hand is pure parsing:**

Parsing segment looks at each character of a segment once. For each character it
performs few comparisons and arithmetic operations to convert a base64 character
into an integer value it represents. Then it performs few bitwise operations to
incorporate this integer value into a larger integer value. Then it stores
decoded value into an array and moves to the next part of the segment.
Segments are limited to 5 elements.

**On the other hand caching:**
1. To look up a cached value we traverse all the characters of the segment
   once to find its end;
2. We extract the substring, which requires allocation and potentially
   copying depending on how strings are implemented in a concrete JS VM;
3. We use this string as a key in a dictionary, which:
    1. first requires VM to compute hash for this string (traversing it again
       and performing various bitwise operations on individual characters),
       this might also require VM to internalize the string (depending on
       implementation);
    2. then VM has to perform a hash table lookup, which requires probing and
       comparing key by value with other keys (which might require it again
       to look at individual characters in a string);

Overall it seems that direct parsing should be faster, assuming that JS VM
does good job with individual arithmetic/bitwise operations, simply because
it looks at each individual character only once, where caching requires
traversing the segment 2-4 times just to establish whether we hit the
cache or not.

Profile seems to confirm this too: `KeyedLoadIC_Megamorphic` is a stub used
by V8 to implement keyed lookups like `cachedSegments[str]` in the code above.

Based on these observations I set out to do few experiments. First I checked how
big `cachedSegments` is at the end of the parsing. The smaller it is the more
effecient caching would be as an optimization.

Turns out is was not that small:

```console
Object.keys(cachedSegments).length = 155478
```

## Standalone Microbenchmarks

Now I decided to write a small standalone benchmark:

```js
// Generate a string with [n] segments, segments repeat in a cycle of length
// [v] i.e. segments number 0, v, 2*v, ... are all equal and so are
// 1, 1 + v, 1 + 2*v, ...
// Use [base] as a base value in a segment - this parameter allows to make
// segments long.
//
// Note: the bigger [v], the bigger [cachedSegments] cache is.
function makeString(n, v, base) {
  var arr = [];
  for (var i = 0; i < n; i++) {
    arr.push([0, base + (i % v), 0, 0].map(base64VLQ.encode).join(''));
  }
  return arr.join(';') + ';';
}

// Run function [f] against the string [str].
function bench(f, str) {
  for (var i = 0; i < 1000; i++) {
    f(str);
  }
}

// Measure and report performance of [f] against [str].
// It has [v] different segments.
function measure(v, str, f) {
  var start = Date.now();
  bench(f, str);
  var end = Date.now();
  report(`${v}, ${f.name}, ${(end - start).toFixed(2)}`);
}

async function measureAll() {
  for (let v = 1; v <= 256; v *= 2) {
    // Make a string with 1000 total segments and [v] different ones
    // so that [cachedSegments] has [v] cached segments.
    let str = makeString(1000, v, 1024 * 1024);

    let arr = encoder.encode(str);

    // Run 10 iterations for each way of decoding.
    for (var j = 0; j < 10; j++) {
     measure(j, i, str, decodeCached);
     measure(j, i, str, decodeNoCaching);
     measure(j, i, str, decodeNoCachingNoStrings);
     measure(j, i, arr, decodeNoCachingNoStringsPreEncoded);
     await nextTick();
    }
  }
}

function nextTick() { return new Promise((resolve) => setTimeout(resolve)); }
```

There are three different ways to decode Base64 VLQ segments that I tried
against each other.

The first one `decodeCached` is exactly the same as default
implementation used by `source-map` - which I already provided above:

```js
function decodeCached(aStr) {
  var length = aStr.length;
  var cachedSegments = {};
  var end, str, segment, value, temp = {value: 0, rest: 0};
  const decode = base64VLQ.decode;

  var index = 0;
  while (index < length) {
    // Because each offset is encoded relative to the previous one,
    // many segments often have the same encoding. We can exploit this
    // fact by caching the parsed variable length fields of each segment,
    // allowing us to avoid a second parse if we encounter the same
    // segment again.
    for (end = index; end < length; end++) {
      if (_charIsMappingSeparator(aStr, end)) {
        break;
      }
    }
    str = aStr.slice(index, end);

    segment = cachedSegments[str];
    if (segment) {
      index += str.length;
    } else {
      segment = [];
      while (index < end) {
        decode(aStr, index, temp);
        value = temp.value;
        index = temp.rest;
        segment.push(value);
      }

      if (segment.length === 2) {
        throw new Error('Found a source, but no line and column');
      }

      if (segment.length === 3) {
        throw new Error('Found a source and line, but no column');
      }

      cachedSegments[str] = segment;
    }

    index++;
  }
}
```

The next competitor is `decodeNoCaching`. It's essentially `decodeCached` but
without the cache. Each segment it decoded independently. I also replaced
`Array` with `Int32Array` for `segment` storage.

```js
function decodeNoCaching(aStr) {
  var length = aStr.length;
  var cachedSegments = {};
  var end, str, segment, temp = {value: 0, rest: 0};
  const decode = base64VLQ.decode;

  var index = 0, value;
  var segment = new Int32Array(5);
  var segmentLength = 0;
  while (index < length) {
    segmentLength = 0;
    while (!_charIsMappingSeparator(aStr, index)) {
      decode(aStr, index, temp);
      value = temp.value;
      index = temp.rest;
      if (segmentLength >= 5) throw new Error('Too many segments');
      segment[segmentLength++] = value;
    }

    if (segmentLength === 2) {
      throw new Error('Found a source, but no line and column');
    }

    if (segmentLength === 3) {
      throw new Error('Found a source and line, but no column');
    }

    index++;
  }
}
```

Finally the third variant `decodeNoCachingNoString` tries to avoid
dealing with JavaScript strings altogether by converting the string into
utf8 encoded `Uint8Array`. This optimization is inspired by the fact that
due to the sheer complexity of the hierarchy of different string
representations JS VMs sometimes fail to (or can't) optimize `charCodeAt` down
to a single memory load.

I benchmark both a version that encodes string into utf8 as part of the
iteration and a version that uses preencoded string. This version tries to
estimate how much you can gain if you are able to skip *typed array* to *string*
to *typed array* roundtrip e.g. if you load your source map directly as an
array buffer it might be better to parse it dirrectly from that buffer instead
of converting it to string first.

```js
let encoder = new TextEncoder();
function decodeNoCachingNoString(aStr) {
  decodeNoCachingNoStringPreEncoded(encoder.encode(aStr));
}

function decodeNoCachingNoStringPreEncoded(arr) {
  var length = arr.length;
  var cachedSegments = {};
  var end, str, segment, temp = {value: 0, rest: 0};
  const decode2 = base64VLQ.decode2;

  var index = 0, value;
  var segment = new Int32Array(5);
  var segmentLength = 0;
  while (index < length) {
    segmentLength = 0;
    while (arr[index] != 59 && arr[index] != 44) {
      decode2(arr, index, temp);
      value = temp.value;
      index = temp.rest;
      if (segmentLength < 5) {
        segment[segmentLength++] = value;
      }
    }

    if (segmentLength === 2) {
      throw new Error('Found a source, but no line and column');
    }

    if (segmentLength === 3) {
      throw new Error('Found a source and line, but no column');
    }

    index++;
  }
}
```

And here are the results I got by running my microbenchmark in Chrome Dev
`66.0.3343.3` (V8 `6.6.189`) and Firefox Nightly `60.0a1 (2018-02-11)`:

![Different Decodes](/images/2018-02-03/different-decodes.png)

There are few things to notice here:

* the version that uses caching is slower than anything else on both V8 and SpiderMonkey.
Its performance degrades steeply as number of cache entries growth - while performance of
non-caching versions does not depend on that;
* on SpiderMonkey it pays off to convert string into typed array as part of
parsing, while on V8 character access is fast enough - so it only pays off
to use array if you can move string-to-array convertion out of benchmark
(e.g. you load your data into typed arrays to begin with);

I was curious if V8 team did any active work recently to improve `charCodeAt`
performance - because I remembered rather vividly that for example Crankshaft
never made an effort to specialize `charCodeAt` for a particular string
representation at a call-site and instead expanded `charCodeAt` into a large
chunk of code handling many different string representations, which made loading
characters from strings slower than loading elements from typed arrays.

I trawled V8 issue tracker and found few issues like:

* [Issue 6391: StringCharCodeAt slower than Crankshaft](https://bugs.chromium.org/p/v8/issues/detail?id=6391);
* [Issue 7092: High overhead of String.prototype.charCodeAt in typescript test](https://bugs.chromium.org/p/v8/issues/detail?id=7092);
* [Issue 7326: Performance degradation when looping across character codes of a string](https://bugs.chromium.org/p/v8/issues/detail?id=7326);

All of them actively being worked on, some updates linking to commits from late
January 2018 and onward. Out of curiousity I decided to rerun my microbenchmark
in Chrome Beta and compare against Chrome Dev

![Different Decodes](/images/2018-02-03/different-decodes-v8s.png)

This comparison indeed shows that all those commits by the V8 team were
not for nothing: performance of `charCodeAt` improved drastically from
version `6.5.254.21` to `6.6.189`. Comparing "no cache" and "using array" lines
we can see that in an older V8 `charCodeAt` behaved so much worse that it made
total sense to put an additional overhead and convert the string into `Uint8Array`
just to access it faster. This does not pay off anymore.

However it still pays off to use an array as long as you don't have to pay the
convertion cost. Why is that? To figure that out I run the following code in
tip-of-the tree V8:

```js
function foo(str, i) {
  return str.charCodeAt(i);
}

let str = "fisk";

foo(str, 0);
foo(str, 0);
foo(str, 0);
%OptimizeFunctionOnNextCall(foo);
foo(str, 0);
```

```console
╭─ ~/src/v8/v8 ‹master›
╰─$ out.gn/x64.release/d8 --allow-natives-syntax --print-opt-code --code-comments x.js
```

The command produced a rather [gigantic assembly listing](https://gist.github.com/mraleph/a1f36a67676a8dfef0af081f27f3eb6a)
confirming my suspicion that V8 still does not specialize `charCodeAt` for a
particular string representation. This lowering seems to come from [this code](https://github.com/v8/v8/blob/de7a3174282a48fab9c167155ffc8ff20c37214d/src/compiler/effect-control-linearizer.cc#L2687-L2826)
in V8 sources, which resolves the mystery of why array access is faster than
string `charCodeAt`.

## Parsing Improvements

In light of these lets remove caching of parsed segments from `source-maps`
parsing code and measure the effect.

![Parse and Sort times](/images/2018-02-03/parse-sort-1.png)

Just like our microbenchmarking predicted caching was detrimental to the
overall performance rather than being beneficial: removing it actually
improves parsing times considerably.

# Optimizing Sorting - Algorithmic Improvements

Now that we improved parsing time lets take a look at sorting again.

There are two arrays that are being sorted: `originalMappings` array is being sorted
using `compareByOriginalPositions` comparator and `generatedMappings` array is being
sorted using `compareByGeneratedPositionsDeflated` comparator.

## Optimizing `originalMappings` Sorting

I took at look at `compareByOriginalPositions` first.

```js
function compareByOriginalPositions(mappingA, mappingB, onlyCompareOriginal) {
  var cmp = strcmp(mappingA.source, mappingB.source);
  if (cmp !== 0) {
    return cmp;
  }

  cmp = mappingA.originalLine - mappingB.originalLine;
  if (cmp !== 0) {
    return cmp;
  }

  cmp = mappingA.originalColumn - mappingB.originalColumn;
  if (cmp !== 0 || onlyCompareOriginal) {
    return cmp;
  }

  cmp = mappingA.generatedColumn - mappingB.generatedColumn;
  if (cmp !== 0) {
    return cmp;
  }

  cmp = mappingA.generatedLine - mappingB.generatedLine;
  if (cmp !== 0) {
    return cmp;
  }

  return strcmp(mappingA.name, mappingB.name);
}
```

Here I noticed that mappings are being ordered by `source` component first and
then by all other components. `source` specifies which source file the mapping
originally came from. An obvious idea here is that instead of using a flat
gigantic `originalMappings` array that mixes together mappings from different
source files, we can turn `originalMappings` into array of arrays:
`originalMappings[i]` being an array of mappings from source file with index `i`.
This way we can sort mappings into different `originalMappings[i]` arrays based
on their source as we parse them and then sort individual smaller arrays.

Here is what we do in parsing loop:


```js
if (typeof mapping.originalLine === 'number') {
  // This code used to just do: originalMappings.push(mapping).
  // Now it sorts original mappings already by source during parsing.
  let currentSource = mapping.source;
  while (originalMappings.length <= currentSource) {
    originalMappings.push(null);
  }
  if (originalMappings[currentSource] === null) {
    originalMappings[currentSource] = [];
  }
  originalMappings[currentSource].push(mapping);
}
```

And then after that:

```js
var startSortOriginal = Date.now();
// The code used to sort the whole array:
//     quickSort(originalMappings, util.compareByOriginalPositions);
for (var i = 0; i < originalMappings.length; i++) {
  if (originalMappings[i] != null) {
    quickSort(originalMappings[i], util.compareByOriginalPositionsNoSource);
  }
}
var endSortOriginal = Date.now();
```

The `compareByOriginalPositionsNoSource` comparator is almost exactly the same
as `compareByOriginalPositions` comparator except it does not compare `source`
component anymore - those are guaranteed to be equal due to the way we
constructed each `originalMappings[i]` array.

![Parse and Sort times](/images/2018-02-03/parse-sort-2.png)

This algorithmic change improves sorting times on both V8 and SpiderMonkey and
additionally improves parsing times on V8. Parse time improvement is likely due
to the reduction of cost associated with managing `originalMappings` array:
growing gigantic `originalMappings` array is more expensive than growing
multiple smaller mappings arrays.

## Optimizing `generatedMappings` Sorting

Let us take a look at `generatedMappings` and `compareByGeneratedPositionsDeflated`
comparator.

```js
function compareByGeneratedPositionsDeflated(mappingA, mappingB, onlyCompareGenerated) {
  var cmp = mappingA.generatedLine - mappingB.generatedLine;
  if (cmp !== 0) {
    return cmp;
  }

  cmp = mappingA.generatedColumn - mappingB.generatedColumn;
  if (cmp !== 0 || onlyCompareGenerated) {
    return cmp;
  }

  cmp = strcmp(mappingA.source, mappingB.source);
  if (cmp !== 0) {
    return cmp;
  }

  cmp = mappingA.originalLine - mappingB.originalLine;
  if (cmp !== 0) {
    return cmp;
  }

  cmp = mappingA.originalColumn - mappingB.originalColumn;
  if (cmp !== 0) {
    return cmp;
  }

  return strcmp(mappingA.name, mappingB.name);
}
```

Here we first compare mappings by `generatedLine`. There are likely considerably
more generated lines than original source files so it might not make sense
to split `generatedMappings` into multiple individual arrays.

However when I look at the parsing code I notice the following:

```js
while (index < length) {
  if (aStr.charAt(index) === ';') {
    generatedLine++;
    // ...
  } else if (aStr.charAt(index) === ',') {
    // ...
  } else {
    mapping = new Mapping();
    mapping.generatedLine = generatedLine;

    // ...
  }
}
```

These are the only occurrences of `generatedLine` in this code. This means that
`generatedLine` is growing monotonically - which implies that
`generatedMappings` array is already ordered by `generatedLine` and it does
not make sense to sort the array as whole. Instead we can sort each individual
smaller subarray. We change the code like this:

```js
let subarrayStart = 0;
while (index < length) {
  if (aStr.charAt(index) === ';') {
    generatedLine++;
    // ...

    // Sort subarray [subarrayStart, generatedMappings.length].
    sortGenerated(generatedMappings, subarrayStart);
    subarrayStart = generatedMappings.length;
  } else if (aStr.charAt(index) === ',') {
    // ...
  } else {
    mapping = new Mapping();
    mapping.generatedLine = generatedLine;

    // ...
  }
}
// Sort the tail.
sortGenerated(generatedMappings, subarrayStart);
```

Instead of using `quickSort` for sorting smaller subarrays, I decided to opt in
for using insertion sort (similar to a hybrid strategy that some VMs use for
`Array.prototype.sort`)

```js
const compareGenerated = util.compareByGeneratedPositionsDeflatedNoLine;

function sortGenerated(array, start) {
  let l = array.length;
  let n = array.length - start;
  if (n <= 1) {
    return;
  } else if (n == 2) {
    let a = array[start];
    let b = array[start + 1];
    if (compareGenerated(a, b) > 0) {
      array[start] = b;
      array[start + 1] = a;
    }
  } else if (n < 20) {
    for (let i = start; i < l; i++) {
      for (let j = i; j > start; j--) {
        let a = array[j - 1];
        let b = array[j];
        if (compareGenerated(a, b) <= 0) {
          break;
        }
        array[j - 1] = b;
        array[j] = a;
      }
    }
  } else {
    quickSort(array, compareGenerated, start);
  }
}
```

This yields the following result:

![Parse and Sort times](/images/2018-02-03/parse-sort-3.png)

Sorting times drop drastically, while parsing times slightly increase - that
happens because the code sorting `generatedMappings` as part of the parsing
loop, making our breakdown slightly meaningless. Lets check comparison of
cumulative timings (parsing and sorting together)

## Improvements to Total Time

![Parse and Sort times](/images/2018-02-03/parse-sort-3-total.png)

Now it becomes obvious that we considerably improved overall mappings parsing
performance.

<small markdown="1">[An interesting observation to be made here is that
if we expect `generatedMappings` to be almost always sorted after parsing
(the mappings file used for `source-maps` benchmark actually has this property)
then it would more efficient to simply check whether `generatedMappings`
is sorted before trying to sort it.]</small>

Is there are anything else we could do to improve performance?

It turns out yes: we can pull out a page from asm.js / WASM own playbook
without going full-Rust on our JavaScript code base.

# Optimizing Parsing - Reducing GC Pressure

We are allocating hundreds of thousands `Mapping` objects, which puts
considerable pressure on GC - in reality we don't really need those objects
to be objects - we can pack them into a typed array. Here is how I did it.

<small markdown="1">[Few years ago I was really excited about
[Typed Objects](https://github.com/nikomatsakis/typed-objects-explainer) proposal
which would allow JavaScript programmers to define structs and arrays of structs and
all other amazing things that would come quite handy here. Unfortunately champions
working on that proposal moved away to work on other things leaving us
with a choice to write these things either manually or in C++ &#x1f61e;]</small>

First of all, I changed `Mapping` from a normal object into a wrapper that
points into a gigantic typed array that would contain all our mappings.

```js
function Mapping(memory) {
  this._memory = memory;
  this.pointer = 0;
}
Mapping.prototype = {
  get generatedLine () {
    return this._memory[this.pointer + 0];
  },
  get generatedColumn () {
    return this._memory[this.pointer + 1];
  },
  get source () {
    return this._memory[this.pointer + 2];
  },
  get originalLine () {
    return this._memory[this.pointer + 3];
  },
  get originalColumn () {
    return this._memory[this.pointer + 4];
  },
  get name () {
    return this._memory[this.pointer + 5];
  },
  set generatedLine (value) {
    this._memory[this.pointer + 0] = value;
  },
  set generatedColumn (value) {
    this._memory[this.pointer + 1] = value;
  },
  set source (value) {
    this._memory[this.pointer + 2] = value;
  },
  set originalLine (value) {
    this._memory[this.pointer + 3] = value;
  },
  set originalColumn (value) {
    this._memory[this.pointer + 4] = value;
  },
  set name (value) {
    this._memory[this.pointer + 5] = value;
  },
};
```

Then I adjusted the parsing and sorting code to use it like this:

```js
BasicSourceMapConsumer.prototype._parseMappings = function (aStr, aSourceRoot) {
  // Allocate 4 MB memory buffer. This can be proportional to aStr size to
  // save memory for smaller mappings.
  this._memory = new Int32Array(1 * 1024 * 1024);
  this._allocationFinger = 0;
  let mapping = new Mapping(this._memory);
  // ...
  while (index < length) {
    if (aStr.charAt(index) === ';') {

      // All code that could previously access mappings directly now needs to
      // access them indirectly though memory.
      sortGenerated(this._memory, generatedMappings, previousGeneratedLineStart);
    } else {
      this._allocateMapping(mapping);

      // ...

      // Arrays of mappings now store "pointers" instead of actual mappings.
      generatedMappings.push(mapping.pointer);
      if (segmentLength > 1) {
        // ...
        originalMappings[currentSource].push(mapping.pointer);
      }
    }
  }

  // ...

  for (var i = 0; i < originalMappings.length; i++) {
    if (originalMappings[i] != null) {
      quickSort(this._memory, originalMappings[i], util.compareByOriginalPositionsNoSource);
    }
  }
};

BasicSourceMapConsumer.prototype._allocateMapping = function (mapping) {
  let start = this._allocationFinger;
  let end = start + 6;
  if (end > this._memory.length) {  // Do we need to grow memory buffer?
    let memory = new Int32Array(this._memory.length * 2);
    memory.set(this._memory);
    this._memory = memory;
  }
  this._allocationFinger = end;
  let memory = this._memory;
  mapping._memory = memory;
  mapping.pointer = start;
  mapping.name = 0x7fffffff;  // Instead of null use INT32_MAX.
  mapping.source = 0x7fffffff;  // Instead of null use INT32_MAX.
};

exports.compareByOriginalPositionsNoSource =
  function (memory, mappingA, mappingB, onlyCompareOriginal) {
  var cmp = memory[mappingA + 3] - memory[mappingB + 3];  // originalLine
  if (cmp !== 0) {
    return cmp;
  }

  cmp = memory[mappingA + 4] - memory[mappingB + 4];  // originalColumn
  if (cmp !== 0 || onlyCompareOriginal) {
    return cmp;
  }

  cmp = memory[mappingA + 1] - memory[mappingB + 1];  // generatedColumn
  if (cmp !== 0) {
    return cmp;
  }

  cmp = memory[mappingA + 0] - memory[mappingB + 0];  // generatedLine
  if (cmp !== 0) {
    return cmp;
  }

  return memory[mappingA + 5] - memory[mappingB + 5];  // name
};
```

As you can see readability does suffer quite a bit. Ideally I would prefer to
allocate temporary `Mapping` objects and rely on allocation sinking to
take care of those objects, but in my experiments SpiderMonkey could not deal
with them well enough, that is why I opted for much more verbose and error
prone code.

Rerunning benchmark confirms that alleviating GC pressure yields a nice
improvement

![After reworking allocation](/images/2018-02-03/parse-sort-4.png)

![After reworking allocation](/images/2018-02-03/parse-sort-4-total.png)

Interestingly enough on SpiderMonkey this approach improves both parsing
*and* sorting times, which came as a surprise to me.

## SpiderMonkey Performance Cliff

As I way playing with this code I also discovered a confusing performance
cliff in SpiderMonkey: when I increased the size of preallocated memory
buffer to 64MB to gauge reallocation costs, benchmark showed a sudden
slow down after 7th iteration.

![After reworking allocation](/images/2018-02-03/parse-sort-5-total.png)

This looked like some sort of polymorphism to me, but I could not immediately
figure out how changing the size of an array can result in polymorphic behavior.

Puzzled I reached out to a SpiderMonkey hacker [Jan de Mooij](https://twitter.com/jandemooij) who
very [quickly identified](https://bugzilla.mozilla.org/show_bug.cgi?id=1437471)
an asm.js related optimization from 2012 as a culprit... then he went and removed
it from SpiderMonkey so that nobody hits this confusing cliff again.

# Optimizing Parsing - Using `Uint8Array` Instead of a String.

Finally if we start using `Uint8Array` instead of string for parsing we get
the yet another small improvement.

![After reworking allocation](/images/2018-02-03/parse-sort-6-total.png)

<small markdown="1">[This improvement is predicated on rewriting `source-maps` to
parse mappings directly from typed arrays, instead of using JavaScript string
and parsing it with `JSON.decode`. I did not do such rewrite but I don't
anticipate any issues.]</small>

# Total Improvements Against the Baseline

Here is where we started:

```console
$ d8 bench-shell-bindings.js
...
[Stats samples: 5, total: 24050 ms, mean: 4810 ms, stddev: 155.91063145276527 ms]
$ sm bench-shell-bindings.js
...
[Stats samples: 7, total: 22925 ms, mean: 3275 ms, stddev: 269.5999093306804 ms]
```

and this is where we are finishing

```console
$ d8 bench-shell-bindings.js
...
[Stats samples: 22, total: 25158 ms, mean: 1143.5454545454545 ms, stddev: 16.59358125226469 ms]
$ sm bench-shell-bindings.js
...
[Stats samples: 31, total: 25247 ms, mean: 814.4193548387096 ms, stddev: 5.591064299397745 ms]
```

![After reworking allocation](/images/2018-02-03/parse-sort-final.png)

![After reworking allocation](/images/2018-02-03/parse-sort-final-total.png)

This is a factor of 4 improvement!

It might be also worth noting that we are still sorting all `originalMappings`
arrays eagerly even though this is not really needed. There are two operations
that use `originalMappings`:

* `allGeneratedPositionsFor` that returns all generated positions for the
given line in the original source;
* `eachMapping(..., ORIGINAL_ORDER)` which iterates over all mappings in
their original order.

If we assume that `allGeneratedPositionsFor` is the most common operation and
that only a handful of `originalMappings[i]` arrays would be queried we can
vastly improve parsing time by sorting `originalMappings[i]` arrays
lazily whenever we actually need to search one of them.

Finally a comparison of V8 from Jan 19th to V8 from Feb 19th with and without
[untrusted code mitigations](https://github.com/v8/v8/wiki/Untrusted-code-mitigations).

![After reworking allocation](/images/2018-02-03/parse-sort-final-total.png)

# Learnings

## For a JavaScript Developer

### Profiler Is Your Friend

Profiling and fine grained performance tracking in various shapes and forms is
the best way to stay on top of the performance. It allows you to localize
hot-spots in your code and also reveals potential issues in the underlying
runtime. For this particular reason don't shy away from using low-level
profiling tools like `perf` - "friendly" tools might not be telling you the
whole story because they hide lower level.

Difference performance problems require different approach to profiling and
visualizing collected profiles. Make sure to familiarize yourself with a wide
spectrum of available tools.

### Algorithms Are Important

Being able to reason about your code in terms of abstract complexity is
an important skill. Is it better to quick-sort one array with 100K elements or
quick-sort 3333 30-element subarrays?

A bit of mathematics can guide us (\\(100000 \log 100000\\) is 3 times larger than
\\(3333 \times 30 \log 30\\)) - and the larger your data is the more important
it usually is to be able to do a tiny bit of mathematics.

In addition to knowing your logarithms, you need to posses a healthy amount
of common sense and be able to evaluate how your code would be used on average
and in the worst case: which operations are common, how the cost of expensive
operations can be amortized, what the penalty for amortizing expensive
operations?

### VMs Are Work in Progress. Bug Developers!

Do not hesitate to reach out to developers to discuss strange performance
issues. Not everything can be solved just by changing your own code. The Russian
proverb says *&laquo;It's not gods who make pots!&raquo;*. VM developers are
people and just like all others they make mistakes. They are also quite good
at fixing those mistakes once you reach out to them. One mail or chat message
or a DM might save you days of digging through foreign C++ code.

### VMs Still Need a Bit of Help

Sometimes you need to write low-level code or know low-level details to
squeeze the last drops of that performance juice out of JavaScript.

One could prefer a better language level facilities to achieve that, but
it remains to be seen if we ever get there.

## For a Language Implementor/Designer

### Clever Optimizations Must be Diagnosable

If you runtime has any sort of clever optimizations built in you need to also
provide a straightforward tool to diagnose when these optimization fail and
deliver an actionable feedback to the developer.

In context of languages like JavaScript this at minimum means that tools like
profiler should also provide you a way to inspect individual operations to
figure out whether VM specializes them well and it it does not - what is
the reason for that.

This sort of introspection should not require building custom versions of
the VM with magic flags and then treading should megabytes of undocumented
debug output. This sort of tools should be right there, when you open your
DevTools window.

### Language and Optimizations Must Be Friends

Attempt to foresee where the language lacks features that make it hard to
write well performing code. Are your users on the market for a way to layout
and manage memory manually? I am sure they are. If your language is even
remotely popular users would eventually succeed in writing code that performs
poorly. Weight the cost of adding language features that fix performance
problems against solving the same performance problems by other means (e.g.
by more sophisticated optimizations or by asking users to rewrite their code
in Rust).

This works the other way around to: if your language has features make sure
that they perform reasonably well and their performance is both well understood
by users and can be easily diagnosed. Invest in making your whole language
optimized, instead of having a well performing code and surrounded by
poorly performing long tail of rarely used features.

<script type="text/javascript" src="/js/mathjax.js">
</script>

