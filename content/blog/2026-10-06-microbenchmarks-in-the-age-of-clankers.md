---
layout: blogpost
title: 'Microbenchmarks in the age of clankers'
date: 2026-10-06
---

One of the first computer games I have encountered on a PC was an MS DOS version
of [Prince of Persia](https://en.wikipedia.org/wiki/Prince_of_Persia_(1989_video_game)).
I have not played it for 30+ years, but the image of protagonist falling to
his death and being impaled by spikes at the bottom of the pit still stands
vividly before my eyes.

<sidenote>I really enjoyed reading <a href="https://www.jordanmechner.com/en/books/journals/">The Making of Prince of Persia</a> by Jordan Mechner, who was keeping detailed journals of his game development journey.</sidenote>

What does it have to do with microbenchmarks? Well, that's the very same
image that stands before my eyes when I hear that somebody fell into the
very same microbenchmarking trap I have been warning about for as long
as I have been writing posts for my blog.

That is even more surprising in todays age of clankers. They will gladly take
care of minutiae of HOW for you as long as you remember to ask the right
question (and make sure to check the result).

With microbenchmarks, as I have written [before](2024-11-27-microbenchmarks-are-experiments.html),
the right question is _not_ whether a measurement produced by the benchmark **A**
is larger or smaller than a measurement produced by benchmark **B**, but
rather _WHY_ these numbers are the way they are. Deriving decisions from
numbers without knowing the reason hiding behind these numbers will invariably
lead to incorrect conclusions.

<img src="/images/2026-10-06/prince-of-persia.png" class="centered">

Few days ago I saw a [post](https://filiph.net/text/dart-for-loops-performance.html)
from Filip Hráček comparing execution speed of different Dart loops. As I was
scrolling through the text a few things jumped out at me:

1. We treat the system as a black box and try to make conclusions about its
internals purely from a singular measurement.
2. Benchmarks are not adversarial enough to produce meaningful data.
3. A huge gap between AOT and JIT performance is mentioned at the end of the
post but left without interpretation.

# The system is not a black box

The first mistake that the post makes is that it tries to declare whether
something is optimized or not purely based on a single number that comes out
of the benchmark. It's like trying to reconstruct my commute route from
the time it took me to reach _Copenhagen_ from _Aarhus_. If I tell you it
took me 12 hours you probably decide that I biked... while in reality I drove
but my car broke several times on the way and I had to walk and take public
transport for the last stretch.

Don't try to divine whether or not something is optimized by looking at single
number. You do not have to do that. The system is open - you can actually look
at the generated code and figure it out from there. There many different ways
to do it, the simplest of them being something like this:

```console
$ dart compile exe -v                                              \
    --extra-gen-snapshot-options=--print-flow-graph-optimized      \
    --extra-gen-snapshot-options=--disassemble-optimized           \
    --extra-gen-snapshot-options=--code-comments                   \
    --extra-gen-snapshot-options=--print-flow-graph-filter=FILTER ...
```

It's also a good idea to look at the CPU profile collected using `perf`,
`simpleperf`, Instruments or whatever tool you like to see where the code
is actually spending time - then you will immediately know whether your
benchmark is actually measuring what you think it is measuring.

# Benchmarks must be adversarial

It is well understood that to measure peak performance of a dynamically
optimized system you must include warmup into your benchmark. It is well
understood that you need to make it harder for compiler to throw the whole
benchmark away as dead code But that's just a tip of the iceberg.

<sidenote>It is also well understood that these systems are so complex that they don't always exhibit stable behavior even after warmup, see <a href="https://arxiv.org/abs/1602.00602" target="_blank">Virtual Machine Warmup Blows Hot and Cold</a></sidenote>

To write good benchmarks you need to understand more about underlying
execution layers. Classical example of that is that benchmarking binary search
by repeating `binarySearch(list, item)` vs repeating
`binarySearch(list, randomItems[i])` will produce two different numbers. Why?
_Branch prediction_. By repeating the same search again and again we allow
CPU to keep hitting the streak of successful predictions, randomizing input data
throws a wrench into this machinery, saturates the predictor and allows us to
see a completely different picture.

When micro-benchmarking high-level programming languages be it Dart or
JavaScript you need to have at least some understanding of underlying cost
model for core operations that your benchmark performs. What is the baseline
cost of these operations as dictated by language semantics? What is execution
environment doing to reduce this cost? Can it fail?

In **C** an array access `a[i]` is just a pointer dereference
`*(a + i)`, there is nothing complicated going behind the scenes - it's just an
`ldr` or `mov` instruction at the end. In **Dart** `a[i]` is a method call
`a.operator[](i)`. How that method call ends up executing on the CPU depends
on the execution mode (native JIT/AOT, JS, Wasm) and what compiler knows
about your program.

<sidenote>Well, the rabbit hole of course goes deeper because the cost of that <code>ldr</code> depends on other factors, like whether or not it hits the CPU cache.</sidenote>

Take a look at this program:

```dart
@pragma('vm:never-inline')
int foo(List<int> list) => list[0];

@pragma('vm:never-inline')
int bar(List<int> list) => list[0];

@pragma('vm:never-inline')
int baz(List<int> list) => list[0];

@pragma('vm:never-inline')
int quux(List<int> list) => list[0];

void main(List<String> args) {
  repeat(() {
    foo(List.filled(10, 0, growable: true));
    bar(List.filled(10, 0, growable: false));
    baz(List.filled(10, 0, growable: args.contains('--baz-growable')));
    quux(List.filled(10, 0, growable: true));
    quux(List.filled(10, 0, growable: false));
  });
}
```

On Dart VM in JIT mode after warmup:

<sidenote>JIT specializes code by using <a href="/blog/2015-01-11-whats-up-with-monomorphism.html" target="_blank" class="equity-caps">inline caches</a> to record concrete classes observed by individual callsites.</sidenote>

* `foo` will be a speculative direct access to a growable list, effectively
equivalent to:
    ```cpp
    deoptIfNot(list, growableListCid);
    checkBound(list->length, index);
    return *(list->data + elementOffset(index))
    ```
* `bar` will be speculative direct access to non-growable list:
    ```cpp
    deoptIfNot(list, fixedLengthListCid);
    checkBound(list->length, index);
    return *(list + elementOffset(index))
    ```
* `baz` will be the same as either `foo` or `bar` depending on the command line
args
* `quux` will be polymorphically inlined version that contains both
possibilities:
   ```
   if (classId(list) == growableListCid) {
     checkBound(list->length, index);
     result = *(list->data + elementOffset(index));
   } else {
     deoptIfNot(list, fixedLengthList);
     checkBound(list->length, index);
     result = *(list + elementOffset(index));
   }
   return result;
   ```

In AOT mode this will be different:

<sidenote>AOT specializes code by performing a global <span class="equity-caps">type flow analysis</span> - it's a static analysis so inferred information is approximate.</sidenote>

* `foo` will be a direct access to a growable list at fixed index:
    ```cpp
    checkBound(list->length, 0);
    return *(list->data + elementOffset(0))
    ```
* `bar` will be a direct access to non-growable list at a fixed index:
    ```cpp
    checkBound(list->length, 0);
    return *(list + elementOffset(0))
    ```
* `baz` and `quux` will be the same: an indirect call via a global dispatch
table (GDT)
   ```cpp
   return GDT[list->cid + selectorOffset(List.operator[])](list);
   ```

Obviously the underlying costs are very different between these, so a benchmark
that is written without taking this into account will provide data which does
not cover the full spectrum of possibilities.

# Doubt Everything

13 years ago in Lisbon at LXJS I gave [my very first talk](https://www.youtube.com/watch?v=65-RbBwZQdU)
about microbenchmarking. There I referred to <a href="https://en.wikipedia.org/wiki/Ren%C3%A9_Descartes" class="equity-caps" target="_blank">René Descartes</a>
and his philosophy of <a href="https://en.wikipedia.org/wiki/Cartesian_doubt"  class="equity-caps" target="_blank">Cartesian doubt</a>.

Descartes was not so much into microbenchmarking himself, but if he were he would
certainly write some good ones:

> It is some years now since I realized how many false opinions I had
> accepted as true from childhood onwards, and that, whatever I had
> since built on such shaky foundations, could only be highly doubtful.
> Hence I saw that at some stage in my life the whole structure would
> have to be utterly demolished, and that I should have to begin again
> from the bottom up if I wished to construct something lasting and
> unshakeable in the sciences.
>
> - First Meditation

In the case of Filip's loop benchmark even ignoring everything else I have
said above the huge gap between JIT and AOT should have immediately ignited
the red lamp of doubt. The alarm bells should have started ringing and
benchmark should have been examined closer with appropriate tools.

# Just employ a clanker

The truth here is that I feel a tiny bit redundant writing all of this because
you don't have to be me and know Dart AOT compiler flags by heart or
endure my preaching about methodology. You can _just_ employ a clanker. I think
it is probably a mistake to not to. They are rather good at building and
using tools and you can always double check what they came up with or steer
them back into the right thing if they go off rails.

I have tried two things:

* Ask it to look at the benchmark and tell me why AOT performs worse than JIT.
It came back with exactly the same answer I got manually. The issue is fairly
trivial so no surprise here - at the current stage I would be more surprised if
it failed to figure it out. It did end up using my SDK checkout to do it rather
than using installed SDK, so may be it is an argument for wiring these options
more prominently into `dart compile exe`.
* Ask it to build me a command line tool for profiling on Mac OS and use to
profile the benchmark. It did it - and the result highlighted the same problem
which can be quickly glimpsed by inspecting compiler IL. On Linux you can just
ask it to use `perf` and it will do that. But I always wanted a CLI alternative
to Instruments but never bothered to write things.

Of course clankers can get confused, but at the very least you can employ them
to make you tools to get all necessary data out and then review the data (and
the tools) yourself.

# Back to Benchmark itself

Start by dumping benchmark IL:

```
$ dart compile exe -DLOOP_VARIANT=for-loop -v                  \
  --extra-gen-snapshot-options=--print-flow-graph-optimized    \
  --extra-gen-snapshot-options=--print-flow-graph-filter=main_ \
  lib/main.dart
```

The core loop looks like this:

```
 14: B7[join]:38 pred(B2, B5) {
      v111 <- phi(v186 T{_Smi}, v118) alive [0, 4611686018427387903] int64 T{<:int}
      v185 <- phi(v153, v117 T{<:num}) alive T{<:num}
}
 15:     ParallelMove fp[-1] <- r5
 16:     CheckStackOverflow:44(stack=0, loop=1)
 18:     v173 <- LoadField(v5 T{_GrowableList} . GrowableObjectArray.length) [0, 576460752303423487] T{_Smi}
 20:     v176 <- UnboxInt64(v173 T{_Smi}) [v173, v173] int64
 22:     Branch if RelationalOp(<, v111, v176 T{_Smi}) T{bool} goto (5, 8)
 24: B5[target]:26
 26:     v123 <- LoadField(v5 T{_GrowableList} . GrowableObjectArray.data) T{_List}
 28:     v187 <- LoadIndexed:32([_List] v123, v111 T{<:int}) [-9223372036854775808, 9223372036854775807] T{<:int}
 30:     v180 <- UnboxInt64(v187 T{<:int}) [-9223372036854775808, 9223372036854775807] int64
 32:     v167 <- BinaryInt64Op(* [tr], v180 T{<:int}, v180 T{<:int}) [-9223372036854775808, 9223372036854775807] int64
 34:     v168 <- BinaryInt64Op(* [tr], v180 T{<:int}, v167) [-9223372036854775808, 9223372036854775807] int64
 36:     v182 <- BoxInt64(v168) [-9223372036854775808, 9223372036854775807] T{<:int}
 38:     v199 <- LoadClassId(v185 T{<:num}) int64
 40:     MoveArgument(sp[1] <- v185 T{<:num})
 42:     MoveArgument(sp[0] <- v182 T{<:int})
 43:     ParallelMove r0 <- r1
 44:     v117 <- DispatchTableCall( cid=v199 num.+<0>, v185 T{<:num}, v182 T{<:int}) T{<:num}
 45:     ParallelMove r1 <- r0, r0 <- fp[-1]
 46:     v118 <- BinaryInt64Op(+ [tr], v111 T{<:int}, v188 T{_Smi}) [1, v176] int64
 48:     ParallelMove r5 <- r5, r4 <- r1, r2 <- fp[-3], r3 <- fp[-2] goto:42 B7
```

From which we can conclude that:

```dart
num sum = 0;
for (var i = 0; i < list.length; i++) {
  sum += pow(list[i], 3);
}
```

Ended up doing a method call to compute `sum + pow(...)` instead of doing
simple integer arithmetic. If we profile this code we will discover that it
spends most of the time (85%) in the runtime system adding 64-bit integers in
the slowest way possible.

This fundamentally means that the benchmark is not measuring what it intended
to measure and instead measuring something else entirely.

This can be trivially fixed by avoid `num` type altogether, which is something
that we always recommend anyway: `num` is a type which mixes two completely
different numeric types: 64-bit integer and double precision floating point
number. These types can't be efficiently operated upon in a uniform fashion
so it is better to avoid it.

<sidenote>JIT does not suffer from the same problem because it leans on dynamic type feedback.</sidenote>

```dart
int sum = 0;
for (var i = 0; i < list.length; i++) {
  sum += pow(list[i], 3) as int;
}
```

Fixing this aligns JIT and AOT performance on the baseline test (`for-loop`) and
reveals performance differences between different loop styles which were
previously hiding in the shadow of a much bigger performance problem, e.g.
`for-in-indexed` is around 2.5-3x slower in this _particular benchmark_, after
adjusting the code a bit to avoid extremely expensive `doNotOptimize(...)` which
again was hiding actual costs.

If we look back at what I have said above in <a href="#benchmarks-must-be-adversarial" class="equity-caps">Benchmarks must be adversarial</a>
and update the benchmark to include obscure the underlying type of the list
being iterated:

```dart
// Compile no longer knows if list is growable or non-growable. VM does not
// have uniform representation for these.
final list = List<int>.generate(kListSize, (i) => i, growable: !args.contains('fixed'));
```

Then we discover that:

1. `for-loop` iterating over a list instance of unknown concrete type is
roughly 5x slower than `for-loop` iterating over a list which is known to the
compiler to be a built-in growable list.
2. `for-loop` iterating over a list instance of unknown concrete type is
roughly 1.5x faster than `for-in-indexed` over a list instance of unknown
concrete type.
3. `for-each` iterating over a list instance of unknown concrete type is
actually 25% faster than `for-loop` over a list instance of unknown
concrete type, which reverses the relationship between these two.

We could explore more things here (e.g. look at how `dart2js` or `dart2wasm`
deal with this), but I think you get the message: don't just look at one
number, it is meaningless by itself. Look at many numbers, look at the code
and profiles.

And probably ask your clanker to help you with that.
