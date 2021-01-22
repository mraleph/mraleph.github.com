---
layout: blogpost
title: 'Micro&#8203;benchmarking Dart (Part 1)'
date: 2021-01-21
redirect_from:
  - blog/2020/01/11/microbenchmarking-dart-part-1.html
---

In the past few months I have started receiving more and more questions about
performance of some specific Dart operations. Here is an example of such a
question asked by [Romain Rastel](https://twitter.com/lets4r) in the context
of his work on [improving performance of ChangeNotifier](https://github.com/flutter/flutter/issues/71900)
in Flutter.

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Looks like creating a fixed-length list with a small number of items, can be, sometimes a lot less performant than creating a growable list. <a href="https://t.co/B5opjZkmrX">pic.twitter.com/B5opjZkmrX</a></p>&mdash; Romain Rastel 💙 (@lets4r) <a href="https://twitter.com/lets4r/status/1333517264281329666?ref_src=twsrc%5Etfw">November 30, 2020</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

Given my experience I knew *exactly* what was going wrong in this particular
benchmark after the very first glance... but for the sake of storytelling
let me pretend that I did not. How would I approach this then?

I would normally start by trying to repeat reported numbers. In this particular
case I would start by creating an empty Flutter application

```console
$ flutter create ubench
$ cd ubench
```

then in `lib/benchmark.dart` I'd put the following code <small class="sidenote">This code was taken from Romain's <a href="https://gist.github.com/letsar/ebc99e00540e60d3ec99636108e52e6a">gist</a> with a minor fix: in the original version benchmark names were swapped by accident, so <code>fixed-length</code> benchmark was allocating growable lists and vice versa.</small>

```dart
// ubench/lib/benchmark.dart
import 'package:benchmark_harness/benchmark_harness.dart';

abstract class Benchmark extends BenchmarkBase {
  const Benchmark(String name) : super(name);

  @override
  void exercise() {
    for (int i = 0; i < 100000; i++) {
      run();
    }
  }
}

class GrowableListBenchmark extends Benchmark {
  const GrowableListBenchmark(this.length) : super('growable[$length]');

  final int length;

  @override
  void run() {
    List<int>()..length = length;
  }
}

class FixedLengthListBenchmark extends Benchmark {
  const FixedLengthListBenchmark(this.length) : super('fixed-length[$length]');

  final int length;

  @override
  void run() {
    List(length);
  }
}

void main() {
  const GrowableListBenchmark(32).report();
  const FixedLengthListBenchmark(32).report();
}
```

and finally I'd run it in the *release* mode

```console
$ flutter run --release -t lib/benchmark.dart
...
I/flutter (18126): growable[32](RunTime): 31464.890625 us.
I/flutter (18126): fixed-length[32](RunTime): 713.8279800142756 us
```

The result seems to show fixed length lists being 43 times faster
to allocate than growable lists. Should we leave it at that and head
over to refactor our code to use as many fixed-length lists as possible?

Absolutely not... or at least not with an expectation that our code becomes
43 times faster. <span class="sidenote">It does <em>actually</em> make sense to prefer fixed-length lists over growable lists where fixed-length lists are a natural fit. They have slightly smaller memory footprint, are faster to allocate and involve less indirections to access an element. But you should do this choice deliberately based on clear understanding of how things work and not based on raw uninterpreted results of microbenchmarks.</span>

Drawing conclusions from raw microbenchmark numbers without any
sort of critical analysis is a common pitfall associated with
microbenchmarking and we should do our best to avoid falling into it.
Unfortunately `package:benchmark_harness` is not making it easier to avoid such
pitfalls: it provides developers with a way to write microbenchmarks but does
not give them tools or guidance on how to validate your benchmarks and
interpret their results. To make things worse `package:benchmark_harness` does
not even attempt to make it very straightforward to write an accurate
microbenchmark.

Consider for example that I could have written this list benchmark in the
following way, without overriding `exercise` to repeat `run` `100000` times:

```dart
// ubench/lib/benchmark-without-exercise.dart
import 'package:benchmark_harness/benchmark_harness.dart';

// Just using BenchmarkBase directly. Rest is the same.
class GrowableListBenchmark extends BenchmarkBase {
  // ...
}

// Just using BenchmarkBase directly. Rest is the same.
class FixedLengthListBenchmark extends BenchmarkBase {
  // ...
}
```

Running this variant would show that growable lists are only 6 times slower
than fixed length lists

```console
$ flutter run --release -t lib/benchmark-without-exercise.dart
I/flutter (14407): growable[32](RunTime): 1.8629797056305768 us.
I/flutter (14407): fixed-length[32](RunTime): 0.3052065645659146 us.
```

Which benchmark result should I trust? **Neither of them really!** I should look
under the hood and try to understand what exactly is happening.

Flutter and Dart already provide developers with enough tooling to figure out
why benchmark numbers look this way. Unfortunately some of this tooling is
somewhat obscure and hard to discover.

For example, it is well known that you can use `flutter run --profile` to
profile your application with Observatory, however it is not well known that
you can also profile release builds using native profilers (like `simpleperf`
on Android or Instruments on iOS). Similarly it is not known (most likely not
known at all outside of a group of engineers working on the VM) that you can
dump annotated disassembly of a specific method from an AOT build by doing

```console
$ flutter build apk --extra-gen-snapshot-options=--print-flow-graph,\
    --disassemble,\
    --print-flow-graph-filter=FixedLengthListBenchmark.run
```

I could spend the rest of this post explaining how one could use these tools
to understand what exactly is going on in these list benchmarks, but instead
I would like to try and imagine how an integrated tooling for benchmarking
could be built out of the primitives provided by Dart and Flutter. This
tooling should not only run benchmarks, but also automatically provide
enough insight for a developer to spot mistakes they made during benchmarking
and help them interpret the results.

## Preliminary setup

I have forked `benchmark_harness` package into [`mraleph/benchmark_harness`](https://github.com/mraleph/benchmark_harness) on GitHub. All of my <em>prototype</em> code is going to live in a new [`experimental-cli`](https://github.com/mraleph/benchmark_harness/tree/experimental-cli) branch in the fork.

<p style="background: rgba(204, 0, 0, .2); padding: .5em;">From here on I will document an evolution of this experimental benchmarking CLI. I would like to stress a highly experimental nature of this tooling: as you will notice that some of its features will end up depending on a patches to Dart and Flutter SDK internals. It might be weeks or months before these patches land and it will become possible to just merge my changes into upstream version of the harness.</p>

I started by adding a trivial `bin/benchmark_harness.dart` script which would
serve as an entry point to our new benchmarking tooling.

```console
$ git clone git@github.com:mraleph/benchmark_harness.git
$ cd benchmark_harness
$ cat > bin/benchmark_harness.dart
void main() { print('Running benchmarks...'); }
^D
```

Finally I changed `pubspec.yaml` in `ubench` project (remember it is an empty
Flutter project we created to host our benchmarks) to have a path dependency
on my version of `benchmark_harness`

```yaml
# ubench/pubspec.yaml

dependencies:
  # ...
  benchmark_harness:
    path: ../benchmark_harness
  # ...
```

This allows me to run `benchmark_harness` script while in `ubench` project
directory

```console
$ flutter pub get
$ flutter pub run benchmark_harness
Running benchmarks...
```

## Generating benchmarks

Have you ever looked at how `benchmark_harness` runs your benchmarks?

It turns out that this package is doing something rather simple (and to an
extent naive): it starts a `Stopwatch`, then repeatedly calls `exercise`
until 2 seconds elapses according to the stopwatch. Time elapsed divided by
number of times `exercise` was called is the reported benchmark score. Take
a look yourself:

```dart
// benchmark_harness/lib/src/benchmark_base.dart
abstract class BenchmarkBase {
  // Measures the score for the benchmark and returns it.
  double measure() {
    // ...
    // Run the benchmark for at least 2000ms.
    var result = measureFor(exercise, 2000);
    // ...
  }

  // Exercises the benchmark. By default invokes [run] 10 times.
  void exercise() {
    for (var i = 0; i < 10; i++) {
      run();
    }
  }

  // Measures the score for this benchmark by executing it repeatedly until
  // time minimum has been reached.
  static double measureFor(Function f, int minimumMillis) {
    var minimumMicros = minimumMillis * 1000;
    var iter = 0;
    var watch = Stopwatch();
    watch.start();
    var elapsed = 0;
    while (elapsed < minimumMicros) {
      f();
      elapsed = watch.elapsedMicroseconds;
      iter++;
    }
    return elapsed / iter;
  }
}
```

This code unfortunately has an issue which makes it unsuitable for
microbenchmarking: measured loop has a bunch of overhead unrelated to the
`exercise` itself. Most noticeably it gets current time from the OS on
each and every iteration. There is also an overhead associated with
multiple levels of virtual dispatch between measured loop and the body of
`run` method containing an actual operation we want to measure. <span class="sidenote">There was a [PR](https://github.com/dart-lang/benchmark_harness/pull/38) against <code>benchmark_harness</code>, which tried to address the issue of calling <code>Stopwatch.elapsedMilliseconds</code> too often, but it somehow got stuck in limbo despite being approved.</span>

The best way to avoid these overheads it to have a separate measured loop for each benchmark.

Here is how this could look like. User declares microbenchmarks by writing a top-level function marked with `@benchmark` annotation.

```dart
// ubench/lib/main.dart
import 'package:benchmark_harness/benchmark_harness.dart';

const N = 32;

@benchmark
void allocateFixedArray() {
  List.filled(N, null, growable: false);
}

@benchmark
void allocateGrowableArray() {
  List.filled(N, null, growable: true);
}
```

Benchmarking tooling would then generate an auxiliary source file which contains a measured loop for each benchmark, plus some code to select which benchmarks should run at compile time:

```dart
// ubench/lib/main.benchmark.dart
import 'package:benchmark_harness/benchmark_harness.dart' as benchmark_harness;

import 'package:ubench/main.dart' as lib;

// ...

void _$measuredLoop$allocateFixedArray(int numIterations) {
  while (numIterations-- > 0) {
    lib.allocateFixedArray();
  }
}

// ...

const _targetBenchmark =
    String.fromEnvironment('targetBenchmark', defaultValue: 'all');
const _shouldMeasureAll = _targetBenchmark == 'all';

const _shouldMeasure$allocateFixedArray =
    _shouldMeasureAll || _targetBenchmark == 'allocateFixedArray';

// ...

void main() {
  benchmark_runner.runBenchmarks(const {
    // ...
    if (_shouldMeasure$allocateFixedArray)
      'allocateFixedArray': _$measuredLoop$allocateFixedArray,
    // ...
  });
}
```

The actual measurement would happen in a simple `measure` helper function:

```dart
// benchmark_harness/lib/benchmark_runner.dart

/// Runs the given measured [loop] function with an exponentially increasing
/// parameter values until it finds one that causes [loop] to run for at
/// least [thresholdMilliseconds] and returns [BenchmarkResult] describing
/// that run.
BenchmarkResult measure(void Function(int) loop,
    {required String name, int thresholdMilliseconds = 5000}) {
  var n = 2;
  final sw = Stopwatch();
  do {
    n *= 2;
    sw.reset();
    sw.start();
    loop(n);
    sw.stop();
  } while (sw.elapsedMilliseconds < thresholdMilliseconds);

  return BenchmarkResult(
    name: name,
    elapsedMilliseconds: sw.elapsedMilliseconds,
    numIterations: n,
  );
}
```

We are starting with a very simple implementation, which should nevertheless
satisfy our initial microbenchmarking needs. However for more complex cases
we might want to do something a bit more rigorous: for example once large enough
`numIterations` is found we can repeat `loop(numIterations)` multiple times
and asses statistical properties of observed running times.

### Using [`source_gen`](https://pub.dev/packages/source_gen)

To generate `main.benchmark.dart` we need to parse `main.dart` and find all
functions annotated with `@benchmark` annotation. Fortunately Dart has a
number of canonical tools for code generation which make this really easy.

All I had to do is to depend on `package:source_gen` and to define a subclass of [`GeneratorForAnnotation`](https://pub.dev/documentation/source_gen/latest/source_gen/GeneratorForAnnotation-class.html):

```dart
// benchmark_harness/lib/src/benchmark_generator.dart

class BenchmarkGenerator extends GeneratorForAnnotation<Benchmark> {
  // ...
  @override
  String generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    final name = element.name;
    return '''
void ${_\$measuredLoop\$$name}(int numIterations) {
  while (numIterations-- > 0) {
    lib.${name}();
  }
}
''';
  }
}
```

which I then wrapped in a `Builder`

```dart
// benchmark_harness/lib/builder.dart

Builder benchmarkLibraryBuilder(BuilderOptions options) =>
    LibraryBuilder(BenchmarkGenerator(), generatedExtension: '.benchmark.dart');
```

and finally exposed this `Builder` factory through `build.yaml`

```yaml
# benchmark_harness/build.yaml

builders:
  benchmark:
    import: "package:benchmark_harness/builder.dart"
    builder_factories: ["benchmarkLibraryBuilder"]
    build_extensions: {".dart": [".benchmark.dart"]}
    auto_apply: dependents
    build_to: source
```

That was basically it. Now whenever I run `build_runner build` in `ubench` I will
get `lib/main.benchmark.dart` generated for benchmarks defined in `lib/main.dart`:

```console
ubench $ flutter pub run build_runner build
ubench $ ls lib/*.benchmark.dart
lib/main.benchmark.dart
```

You can see the full source for code generator in this [commit](https://github.com/mraleph/benchmark_harness/commit/474de50c574339b4ed11267d5885bad37060306b).

### Running benchmarks

We can execute individual benchmarks by passing appropriate `--dart-define`
to `flutter run`, for example:

```console
$ flutter run --release --dart-define targetBenchmark=allocateFixedArray -t lib/main.benchmark.dart
Launching lib/main.benchmark.dart on Pixel 3a in release mode...
Running Gradle task 'assembleRelease'...
Running Gradle task 'assembleRelease'... Done                       4.9s
✓ Built build/app/outputs/flutter-apk/app-release.apk (4.9MB).
Installing build/app/outputs/flutter-apk/app.apk...              1,268ms

Flutter run key commands.
h Repeat this help message.
c Clear the screen
q Quit (terminate the application on the device).
I/flutter (12463): benchmark_harness[{"event":"benchmark.running"}]
I/flutter (12463): benchmark_harness[{"event":"benchmark.result","params":{...}}]
I/flutter (12463): benchmark_harness[{"event":"benchmark.done"}]

Application finished.
```

But doing this manually is not exactly what I was aiming for. Instead I am
going to change `bin/benchmark_harness.dart` script to both build benchmarks
and then to run all generated files to collect benchmark results (for full code see [this](https://github.com/mraleph/benchmark_harness/commit/13941c5e0d58c94bf78d694e619dacb4bfc3ba3c) commit).

```dart
// benchmark_harness/bin/benchmark_harness.dart

void main() async {
  // ...
  // Generate benchmark wrapper scripts.
  print(red('Generating benchmark wrappers'));
  'flutter pub run build_runner build'.start(progress: Progress.devNull());

  // Run all generated benchmarks.
  final resultsByFile = <String, Map<String, BenchmarkResult>>{};
  for (var file in find('*.benchmark.dart').toList().map(p.relative)) {
    resultsByFile[file] = await runBenchmarksIn(file);
  }

  // Report results.
  // ...
}

/// Runs all benchmarks in `.benchmark.dart` [file] one by one and collects
/// their results.
Future<Map<String, BenchmarkResult>> runBenchmarksIn(String file) async {
  // ...
}
```

Such helper script makes running benchmarks really straightforward:

```console
$ flutter pub run benchmark_harness
Generating benchmark wrappers
Found 2 benchmarks in lib/main.benchmark.dart
  measuring allocateFixedArray
    benchmark is running
      done
  measuring allocateGrowableArray
    benchmark is running
      done

--------------------------------------------------------------------------------

Results for lib/main.benchmark.dart
allocateFixedArray: 0.0000030226074159145355 ms/iteration (fastest)
allocateGrowableArray: 0.00018900632858276367 ms/iteration (62.5 times as slow)
```

## Understanding the results

Now that we have a tool for running microbenchmarks, lets extend it with
support for profiling benchmarks as they are running. This would help us to
understand where benchmark is spending time and confirm that it is
measuring exactly what we want it to measure.

Flutter's *release* builds exclude Dart's builtin profiler so we will have
to use a native profiler instead, for example `simpleperf` on Android.

Android has comprehensive [documentation](https://android.googlesource.com/platform/system/extras/+/master/simpleperf/doc/android_application_profiling.md) for using `simpleperf`, which I am not going to duplicate here. `simpleperf` also comes
with C++ (and Java) code called [`app_api`](https://android.googlesource.com/platform/system/extras/+/master/simpleperf/app_api/cpp/simpleperf.cpp) which can be linked into an application to allow programmatic access to the profiler.

In reality `app_api` does not do anything overly fancy: it just runs
`simpleperf` binary with the right command line options. That's why I decided
to just port relevant parts of `app_api` to pure Dart. <span class="sidenote">We could also bind to C++ version of `app_api` using Dart FFI, but that requires packaging this C++ into a <em>Flutter plugin</em>, which complicates things, because `benchmark_harness` is a pure Dart package and it can't depend on a Flutter plugin package.</span>

```dart
// benchmark_harness/lib/src/simpleperf/profiling_session.dart

class ProfilingSession {
  Future<void> start(
      {RecordingOptions options = const RecordingOptions()}) async {
    // ...
    await _startSimpleperfProcess(options);
  }

  Future<void> _startSimpleperfProcess(RecordingOptions options) async {
    final simpleperfBinary = await _findSimplePerf();
    _simpleperf = await Process.start(
      simpleperfBinary,
      [
        'record',
        '--log-to-android-buffer',
        '--log',
        'debug',
        '--stdio-controls-profiling',
        '--in-app',
        '--tracepoint-events',
        '/data/local/tmp/tracepoint_events',
        '-o',
        options.outputFilename ?? _makeOutputFilename(),
        '-e',
        options.event,
        '-f',
        options.frequency.toString(),
        '-p',
        _getpid().toString(),
        ..._callgraphFlagsFrom(options),
      ],
      workingDirectory: simpleperfDataDir,
    );
    // ...
  }
}
```

Then I adjusted `benchmark_runner.dart` to run benchmark it just measured
under the profiler and save profile into a `perf-$benchmarkName.data`
file. This file will be created in application's data directory:

```dart
Future<void> runBenchmarks(Map<String, void Function(int)> benchmarks) async {
  _event('benchmark.running');
  final profiler = Platform.isAndroid ? ProfilingSession() : null;
  for (var entry in benchmarks.entries) {
    final result = measure(entry.value, name: entry.key);
    _event('benchmark.result', result);

    if (profiler != null) {
      // Run benchmark for the same amount of iterations and profile it.
      await profiler.start(
          options: RecordingOptions(outputFilename: 'perf-${entry.key}.data'));
      entry.value(result.numIterations);
      await profiler.stop();
    }
  }
  _event('benchmark.done');
}
```

NDK also comes with a helper script `api_profiler.py`, which implements two
commands:

* `api_profiler.py prepare` configures your device for profiling - we are going
to call it before running benchmarks;
* `api_profiler.py collect` pulls collected profiles from the device - we
are going to call it after all benchmarks finish running to pull all generated
`perf-*.data` from the device.

### Displaying collected profiling data

NDK's `simpleperf` binary supports both `record` and `report` commands, just
like Linux `perf`. Looking around in the NDK I have also discovered a bunch of helper scripts written in Python (e.g. `report_html.py` which can generate a HTML report). Peaking
into those scripts I have discovered that they make use of `libsimpleperf_report.so` library
which handles parsing and symbolization of collected profiles. The API for
this library is defined at the top of [`simpleperf/report_lib_interface.cpp`](https://android.googlesource.com/platform/system/extras/+/refs/heads/master/simpleperf/report_lib_interface.cpp#34) file in
`simpleperf` sources.

Using [`ffigen`](https://pub.dev/packages/ffigen) I generated `dart:ffi`
based bindings for this library, allowing me to use it from `benchmark_harness`
script to process collected profiling samples:

```dart
final reportLib = report_bindings.NativeLibrary(
    ffi.DynamicLibrary.open(ndk.simpleperfReportLib));

Future<void> _printProfile(String profileData) async {
  final session = reportLib.CreateReportLib();
  reportLib.SetRecordFile(session, Utf8.toUtf8(profileData).cast());

  // Iterate over all collected samples.
  for (;;) {
    final sample = reportLib.GetNextSample(session);
    if (sample == ffi.nullptr) {
      break;
    }
    final period = sample.ref.period;
    final symbol = reportLib.GetSymbolOfCurrentSample(session);

    final dsoName = Utf8.fromUtf8(symbol.ref.dso_name.cast());
    final symbolName = Utf8.fromUtf8(symbol.ref.symbol_name.cast());

    // Process sample for the symbol [symbolName] in dso [dsoName] and collect
    // aggregate statistics (samples per symbol, total sampling period, etc).
    // ...
  }

  // Report top N hottest symbols
}
```

When I run this for the first time I've discovered that `simpleperf` can't
really attribute most of the samples to a meaningful symbol neither for
`libapp.so` (which contains AOT compiled Dart code) nor for `libflutter.so`
(which contains Flutter engine code). Here is the very first report I got:

```console
Hot methods when running allocateGrowableArray:
 88.24% _kDartIsolateSnapshotInstructions (libapp.so)
  4.04% unknown (libflutter.so)
  3.15% unknown ([kernel.kallsyms])
  1.44% pthread_mutex_lock (libc.so)
  1.30% pthread_mutex_unlock (libc.so)
  ...
```

This is not surprising: both of these libraries are stripped and
don't contain any useful symbol information for `simpleperf` to use.

Fortunately, `libflutter.so` symbols can be fetched from Cloud Storage where
build infrastructure is archiving them, e.g. symbols for an ARM64 Android
release build of Flutter engine at commit `e115066d...`
reside in
<code class="wrappable">gs://flutter_infra/flutter/e115066d.../android-arm64-release/symbols.zip</code>. Just few months ago I have written some Dart code for downloading and caching Flutter Engine symbols based on commit hash for [`@flutter-symbolizer-bot`](https://github.com/flutter-symbolizer-bot), so I could just reuse the very same code here.

Getting symbols for `libapp.so` is a more interesting problem. Dart VM AOT
compiler is capable of producing DWARF debug sections in the ELF binaries.
However just passing <code class="wrappable">--extra-gen-snapshot-options=--dwarf-stack-traces</code> does
not get us there: `libapp.so` will still be missing symbols. Inspection of
Flutter CLI source reveals that it simply always [instructs AOT](https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/base/build.dart#L143-L157) compiler to produce
stripped output. <span class="sidenote">Users familiar with advanced Flutter tooling options might know about <code>--split-debug-info=...</code> flag which instructs AOT compiler to produce a separate ELF file
containing just the DWARF sections but none of the snapshot payload itself. This file would be enough for symbolization, but unfortunately does not play well with tools like `llvm-objdump`. GNU `objdump` supports separate debug info discovered through <code>.gnu_debuglink</code>, but some features like intermixing source
and disassembly do not seem to work in this mode.</span>

For prototyping purposes I opted to patch `flutter` CLI to allow a user to
suppress stripping by specifying `--no-strip` in `--extra-gen-snapshot-options`.

Now when we build our benchmark we can preserve DWARF debug information in
`libapp.so` and subsequently use it for symbolization, making our profile
more informative:

```console
Hot methods when running allocateGrowableArray:
 54.17% Precompiled_Stub__iso_stub_AllocateArrayStub (libapp.so)
 14.29% Precompiled______measuredLoop_allocateGrowableArray_21146765_1230 (libapp.so)
  8.01% Precompiled__GrowableList_0150898__GrowableList_0150898__withData_0150898_136 (libapp.so)
  7.63% Precompiled__GrowableList_0150898__GrowableList_0150898__164 (libapp.so)
  4.96% Precompiled__GrowableList_0150898__allocateData_0150898_161 (libapp.so)
  3.66% unknown ([kernel.kallsyms])
```

I then took it one step further and used information available in DWARF to pretty
print symbol names (which `simpleperf` does not seem to do). Fortunately I
did not actually have to parse DWARF by hand, `package:native_stack_traces`
already has all necessary tooling for handling ELF/DWARF parsing for us:

```dart
String _userFriendlyName(Dwarf dwarf, elf_lib.Elf elf, String symbol) {
  final elfSymbol = elf.staticSymbolFor(symbol);
  if (elfSymbol != null) {
    final callInfo = dwarf.callInfoFor(elfSymbol.value);
    if (callInfo != null && callInfo.isNotEmpty) {
      final lastInfo = callInfo.last;
      if (lastInfo is DartCallInfo) {
        return lastInfo.function
            .replaceFirst(r'_$measuredLoop$', 'measured loop for ');
      }
      return lastInfo.toString();
    }
  }
  return symbol.replaceFirst('Precompiled_Stub__iso_stub_', 'Stub::');
}
```

This yields even more readable output:

```console
$ flutter run benchmark_harness report
Results for lib/main.benchmark.dart
allocateFixedArray: 0.000006573274731636047 ms/iteration (fastest)
allocateGrowableArray: 0.00020492076873779297 ms/iteration (31.2 times as slow)

Hot methods when running allocateFixedArray:
 99.64% measured loop for allocateFixedArray (libapp.so)

Hot methods when running allocateGrowableArray:
 54.17% Stub::AllocateArrayStub (libapp.so)
 14.29% measured loop for allocateGrowableArray (libapp.so)
  8.01% new _GrowableList._withData (libapp.so)
  7.63% new _GrowableList (libapp.so)
  4.96% _GrowableList._allocateData (libapp.so)
  3.66% unknown ([kernel.kallsyms])
```

We can now see that benchmarks seem to behave slightly differently: `allocateFixedArray` spends all of its time in its measured loop, while
`allocateGrowableArray` spends time in various methods related to array
allocation.

To understand this better we need to look at the native code generated for both
of these measured loops.

There are different possible ways to implement this, e.g. I could choose to
delegate this task to `perf annotate` or something similar. However `perf`
is rather picky with regards to folder structure when searching for symbols,
and none of the NDK scripts seemed to fit the bill, so I opted to just use
`llvm-objdump` and annotate the result with profiling information.

With some post processing to use Dart VM specific names for reserved registers
like `thr` (reserved for current `Thread` pointer) and to demangle symbol names
(via `_userFriendlyName` helper) we get output like this:

<div class="highlighter-rouge language-console highlight"><pre><code>
Hot methods when running <span class="nf">allocateFixedArray</span>:
 99.64% <span style="font-weight: bold; color: #262626"></span><span style="font-weight: bold">measured loop for allocateFixedArray</span> (libapp.so)
                      0: <span class="k">stp</span>	<span class="nv">fp</span>, <span class="nv">lr</span>, [<span class="nv">sp</span>, <span class="mi">#-16</span>]!
                      4: <span class="k">mov</span>	<span class="nv">fp</span>, <span class="nv">sp</span>
                      8: <span class="k">ldr</span>	<span class="nv">x2</span>, [<span class="nv">fp</span>, <span class="mi">#16</span>]
          <span style="color: #ff8700"> 7.87%</span>      c: <span class="k">ldr</span>	<span class="nv">x16</span>, [<span class="nv">thr</span>, <span class="mi">#64</span>]
          <span style="font-weight: bold; color: #d70000">18.40%</span>     10: <span class="k">cmp</span>	<span class="nv">sp</span>, <span class="nv">x16</span>
          <span style="color: #ff8700"> 9.30%</span>     14: <span class="k">b.ls</span>	<span class="nb">-&gt;60</span>
          <span style="color: #ff8700"> 8.88%</span>     18: <span class="k">cmp</span>	<span class="nv">x2</span>, <span class="nv">null</span>
                     1c: <span class="k">b.eq</span>	<span class="nb">-&gt;68</span>
          <span style="color: #ff8700"> 9.65%</span>     20: <span class="k">asr</span>	<span class="nv">x3</span>, <span class="nv">x2</span>, <span class="mi">#1</span>
                     24: <span class="k">tbz</span>	<span class="nv">w2</span>, <span class="mi">#0</span>, <span class="nb">-&gt;2c</span>
                     28: <span class="k">ldur</span>	<span class="nv">x3</span>, [<span class="nv">x2</span>, <span class="mi">#7</span>]
          <span style="color: #ff8700"> 9.45%</span>     2c: <span class="k">sub</span>	<span class="nv">x2</span>, <span class="nv">x3</span>, <span class="mi">#1</span>
                     30: <span class="k">cmp</span>	<span class="nv">x3</span>, <span class="mi">#0</span>
          <span style="color: #ff8700"> 9.85%</span>     34: <span class="k">b.le</span>	<span class="nb">-&gt;50</span>
          <span style="color: #ff8700"> 9.72%</span>     38: <span class="k">adds</span>	<span class="nv">x0</span>, <span class="nv">x2</span>, <span class="nv">x2</span>
                     3c: <span class="k">b.vc</span>	<span class="nb">-&gt;48</span>
                     40: <span class="k">bl</span>	<span class="nb">Stub::AllocateMintSharedWithoutFPURegsStub</span>
                     44: <span class="k">stur</span>	<span class="nv">x2</span>, [<span class="nv">x0</span>, <span class="mi">#7</span>]
          <span style="color: #ff8700"> 8.90%</span>     48: <span class="k">mov</span>	<span class="nv">x2</span>, <span class="nv">x0</span>
          <span style="color: #ff8700"> 7.60%</span>     4c: <span class="k">b.al</span>	<span class="nb">-&gt;c</span>
                     50: <span class="k">mov</span>	<span class="nv">x0</span>, <span class="nv">null</span>
                     54: <span class="k">mov</span>	<span class="nv">sp</span>, <span class="nv">fp</span>
                     58: <span class="k">ldp</span>	<span class="nv">fp</span>, <span class="nv">lr</span>, [<span class="nv">sp</span>], <span class="mi">#16</span>
                     5c: <span class="k">ret</span>
                     60: <span class="k">bl</span>	<span class="nb">Stub::StackOverflowSharedWithoutFPURegsStub</span>
                     64: <span class="k">b.al</span>	<span class="nb">-&gt;18</span>
                     68: <span class="k">bl</span>	<span class="nb">Stub::NullErrorSharedWithoutFPURegsStub</span>
</code></pre></div>

A developer familiar with ARM assembly language might be able to spot the
issue with our benchmark just from this output (yep, there is obviously an
issue).

However I decided to spend a bit more time on it and overlay the information about
Dart VM compiler's intermediate language on top of the assembly, making
it much easier to grok.

Internally our compiler has support for annotating machine code it
generates with human readable comments, which among other things describe
IL from which a particular piece of machine code was produced.

I have experimented with two different paths I considered taking to get this
information out of the AOT compiler:

- add a flag `--write-code-comments-to=output.json` which tells compiler to dump
offset-to-comment mapping into a JSON file and then ingest this JSON in our
benchmarking CLI.
- add a flag `--write-code-comments-as-synthetic-source-to=comments.txt` which
tells compiler to synthesize one gigantic file out of all code comments and
write offset-to-comment mapping as a DWARF line program into `.debug_line`
section.

In the end I decided that the second approach is better because it makes
it possible for _any_ tool that understands `.debug_line` to display code
comments alongside disassembly (e.g. `gdb` will start displaying it as well).

Here is [my patch](https://github.com/mraleph/sdk/commit/6612e52dc01cc843f04a205b2dc56c2d0d69d852#diff-c21c72c7a0fbe730891dd0c86bd141f23c33fddc11b512025ac7381fbda7563a) against Dart SDK implementing necessary plumbing. With
this in place the only change I had to do was to add `-S` to `llvm-objdump`
invocation and it handled the rest:

<div class="highlighter-rouge language-console highlight"><pre><code>
Hot methods when running <span class="nf">allocateFixedArray</span>:
 99.64% <span style="font-weight: bold; color: #262626"></span><span style="font-weight: bold">measured loop for allocateFixedArray</span> (libapp.so)
                         <span class="c">;; Enter frame</span>
                      0: <span class="k">stp</span>	<span class="nv">fp</span>, <span class="nv">lr</span>, [<span class="nv">sp</span>, <span class="mi">#-16</span>]!
                      4: <span class="k">mov</span>	<span class="nv">fp</span>, <span class="nv">sp</span>
                         <span class="c">;; ParallelMove r2 &lt;- S+2</span>
                      8: <span class="k">ldr</span>	<span class="nv">x2</span>, [<span class="nv">fp</span>, <span class="mi">#16</span>]
                         <span class="c">;; CheckStackOverflow:30(stack=0, loop=1)</span>
          <span style="color: #ff8700"> 7.87%</span>      c: <span class="k">ldr</span>	<span class="nv">x16</span>, [<span class="nv">thr</span>, <span class="mi">#64</span>]
          <span style="font-weight: bold; color: #d70000">18.40%</span>     10: <span class="k">cmp</span>	<span class="nv">sp</span>, <span class="nv">x16</span>
          <span style="color: #ff8700"> 9.30%</span>     14: <span class="k">b.ls</span>	<span class="nb">-&gt;60</span>
                         <span class="c">;; CheckNull:10(v3, NoSuchMethodError) T{int}</span>
          <span style="color: #ff8700"> 8.88%</span>     18: <span class="k">cmp</span>	<span class="nv">x2</span>, <span class="nv">null</span>
                     1c: <span class="k">b.eq</span>	<span class="nb">-&gt;68</span>
                         <span class="c">;; v26 &lt;- UnboxInt64(v3 T{int}) T{int}</span>
          <span style="color: #ff8700"> 9.65%</span>     20: <span class="k">asr</span>	<span class="nv">x3</span>, <span class="nv">x2</span>, <span class="mi">#1</span>
                     24: <span class="k">tbz</span>	<span class="nv">w2</span>, <span class="mi">#0</span>, <span class="nb">-&gt;2c</span>
                     28: <span class="k">ldur</span>	<span class="nv">x3</span>, [<span class="nv">x2</span>, <span class="mi">#7</span>]
                         <span class="c">;; v6 &lt;- BinaryInt64Op(- [tr], v26 T{int}, v32) T{int}</span>
          <span style="color: #ff8700"> 9.45%</span>     2c: <span class="k">sub</span>	<span class="nv">x2</span>, <span class="nv">x3</span>, <span class="mi">#1</span>
                         <span class="c">;; Branch if RelationalOp(&gt;, v26 T{int}, v34) T{bool} goto (3, 5)</span>
                     30: <span class="k">cmp</span>	<span class="nv">x3</span>, <span class="mi">#0</span>
          <span style="color: #ff8700"> 9.85%</span>     34: <span class="k">b.le</span>	<span class="nb">-&gt;50</span>
                         <span class="c">;; v30 &lt;- BoxInt64(v6) T{int}</span>
          <span style="color: #ff8700"> 9.72%</span>     38: <span class="k">adds</span>	<span class="nv">x0</span>, <span class="nv">x2</span>, <span class="nv">x2</span>
                     3c: <span class="k">b.vc</span>	<span class="nb">-&gt;48</span>
                     40: <span class="k">bl</span>	<span class="nb">Stub::AllocateMintSharedWithoutFPURegsStub</span>
                     44: <span class="k">stur</span>	<span class="nv">x2</span>, [<span class="nv">x0</span>, <span class="mi">#7</span>]
                         <span class="c">;; ParallelMove r2 &lt;- r0 goto:28 B4</span>
          <span style="color: #ff8700"> 8.90%</span>     48: <span class="k">mov</span>	<span class="nv">x2</span>, <span class="nv">x0</span>
          <span style="color: #ff8700"> 7.60%</span>     4c: <span class="k">b.al</span>	<span class="nb">-&gt;c</span>
                         <span class="c">;; ParallelMove r0 &lt;- C</span>
                     50: <span class="k">mov</span>	<span class="nv">x0</span>, <span class="nv">null</span>
                         <span class="c">;; Return:36(v0)</span>
                     54: <span class="k">mov</span>	<span class="nv">sp</span>, <span class="nv">fp</span>
                     58: <span class="k">ldp</span>	<span class="nv">fp</span>, <span class="nv">lr</span>, [<span class="nv">sp</span>], <span class="mi">#16</span>
                     5c: <span class="k">ret</span>
                         <span class="c">;; CheckStackOverflowSlowPath</span>
                     60: <span class="k">bl</span>	<span class="nb">Stub::StackOverflowSharedWithoutFPURegsStub</span>
                     64: <span class="k">b.al</span>	<span class="nb">-&gt;18</span>
                         <span class="c">;; slow path check null (nsm) operation</span>
                     68: <span class="k">bl</span>	<span class="nb">Stub::NullErrorSharedWithoutFPURegsStub</span>

Hot methods when running <span class="nf">allocateGrowableArray</span>:
 54.17% Stub::AllocateArrayStub (libapp.so)
 14.29% <span style="font-weight: bold; color: #262626"></span><span style="font-weight: bold">measured loop for allocateGrowableArray</span> (libapp.so)
                         <span class="c">;; Enter frame</span>
                      0: <span class="k">stp</span>	<span class="nv">fp</span>, <span class="nv">lr</span>, [<span class="nv">sp</span>, <span class="mi">#-16</span>]!
                      4: <span class="k">mov</span>	<span class="nv">fp</span>, <span class="nv">sp</span>
                      8: <span class="k">sub</span>	<span class="nv">sp</span>, <span class="nv">sp</span>, <span class="mi">#16</span>
                         <span class="c">;; CheckStackOverflow:8(stack=0, loop=0)</span>
                      c: <span class="k">ldr</span>	<span class="nv">x16</span>, [<span class="nv">thr</span>, <span class="mi">#64</span>]
                     10: <span class="k">cmp</span>	<span class="nv">sp</span>, <span class="nv">x16</span>
                     14: <span class="k">b.ls</span>	<span class="nb">-&gt;94</span>
                         <span class="c">;; v36 &lt;- UnboxedConstant:32(#32) [32, 32] T{_Smi}</span>
                     18: <span class="k">mov</span>	<span class="nv">x0</span>, <span class="mi">#32</span>
                         <span class="c">;; ParallelMove r1 &lt;- S+2, S-2 &lt;- r0</span>
                     1c: <span class="k">ldr</span>	<span class="nv">x1</span>, [<span class="nv">fp</span>, <span class="mi">#16</span>]
                     20: <span class="k">stur</span>	<span class="nv">x0</span>, [<span class="nv">fp</span>, <span class="mi">#-16</span>]
                         <span class="c">;; CheckStackOverflow:30(stack=0, loop=1)</span>
                     24: <span class="k">ldr</span>	<span class="nv">x16</span>, [<span class="nv">thr</span>, <span class="mi">#64</span>]
           0.73%     28: <span class="k">cmp</span>	<span class="nv">sp</span>, <span class="nv">x16</span>
                     2c: <span class="k">b.ls</span>	<span class="nb">-&gt;9c</span>
                         <span class="c">;; CheckNull:10(v3, NoSuchMethodError) T{int}</span>
           0.33%     30: <span class="k">cmp</span>	<span class="nv">x1</span>, <span class="nv">null</span>
                     34: <span class="k">b.eq</span>	<span class="nb">-&gt;a4</span>
                         <span class="c">;; v26 &lt;- UnboxInt64(v3 T{int}) T{int}</span>
           0.30%     38: <span class="k">asr</span>	<span class="nv">x2</span>, <span class="nv">x1</span>, <span class="mi">#1</span>
                     3c: <span class="k">tbz</span>	<span class="nv">w1</span>, <span class="mi">#0</span>, <span class="nb">-&gt;44</span>
                     40: <span class="k">ldur</span>	<span class="nv">x2</span>, [<span class="nv">x1</span>, <span class="mi">#7</span>]
                         <span class="c">;; v6 &lt;- BinaryInt64Op(- [tr], v26 T{int}, v32) T{int}</span>
           0.35%     44: <span class="k">sub</span>	<span class="nv">x1</span>, <span class="nv">x2</span>, <span class="mi">#1</span>
                         <span class="c">;; ParallelMove S-1 &lt;- r1</span>
                     48: <span class="k">stur</span>	<span class="nv">x1</span>, [<span class="nv">fp</span>, <span class="mi">#-8</span>]
                         <span class="c">;; Branch if RelationalOp(&gt;, v26 T{int}, v34) T{bool} goto (3, 5)</span>
          <span style="font-weight: bold; color: #d70000">10.41%</span>     4c: <span class="k">cmp</span>	<span class="nv">x2</span>, <span class="mi">#0</span>
                     50: <span class="k">b.le</span>	<span class="nb">-&gt;84</span>
                         <span class="c">;; PushArgument(v18)</span>
           0.29%     54: <span class="k">ldr</span>	<span class="nv">x16</span>, [<span class="nv">pp</span>, <span class="mi">#5160</span>]
           0.35%     58: <span class="k">stp</span>	<span class="nv">x0</span>, <span class="nv">x16</span>, [<span class="nv">sp</span>, <span class="mi">#-16</span>]!
                         <span class="c">;; StaticCall:10( _GrowableList@0150898.&lt;0&gt; v18, v36, result_type = T{_GrowableList})</span>
                     5c: <span class="k">bl</span>	<span class="nv">new</span> <span class="nv">_GrowableList</span>
           0.33%     60: <span class="k">add</span>	<span class="nv">sp</span>, <span class="nv">sp</span>, <span class="mi">#16</span>
                         <span class="c">;; ParallelMove r2 &lt;- S-1</span>
                     64: <span class="k">ldur</span>	<span class="nv">x2</span>, [<span class="nv">fp</span>, <span class="mi">#-8</span>]
                         <span class="c">;; v30 &lt;- BoxInt64(v6) T{int}</span>
           0.53%     68: <span class="k">adds</span>	<span class="nv">x0</span>, <span class="nv">x2</span>, <span class="nv">x2</span>
                     6c: <span class="k">b.vc</span>	<span class="nb">-&gt;78</span>
                     70: <span class="k">bl</span>	<span class="nb">Stub::AllocateMintSharedWithoutFPURegsStub</span>
                     74: <span class="k">stur</span>	<span class="nv">x2</span>, [<span class="nv">x0</span>, <span class="mi">#7</span>]
                         <span class="c">;; ParallelMove r1 &lt;- r0, r0 &lt;- S-2 goto:28 B4</span>
           0.29%     78: <span class="k">mov</span>	<span class="nv">x1</span>, <span class="nv">x0</span>
                     7c: <span class="k">ldur</span>	<span class="nv">x0</span>, [<span class="nv">fp</span>, <span class="mi">#-16</span>]
           0.38%     80: <span class="k">b.al</span>	<span class="nb">-&gt;24</span>
                         <span class="c">;; ParallelMove r0 &lt;- C</span>
                     84: <span class="k">mov</span>	<span class="nv">x0</span>, <span class="nv">null</span>
                         <span class="c">;; Return:36(v0)</span>
                     88: <span class="k">mov</span>	<span class="nv">sp</span>, <span class="nv">fp</span>
                     8c: <span class="k">ldp</span>	<span class="nv">fp</span>, <span class="nv">lr</span>, [<span class="nv">sp</span>], <span class="mi">#16</span>
                     90: <span class="k">ret</span>
                         <span class="c">;; CheckStackOverflowSlowPath</span>
                     94: <span class="k">bl</span>	<span class="nb">Stub::StackOverflowSharedWithoutFPURegsStub</span>
                     98: <span class="k">b.al</span>	<span class="nb">-&gt;18</span>
                         <span class="c">;; CheckStackOverflowSlowPath</span>
                     9c: <span class="k">bl</span>	<span class="nb">Stub::StackOverflowSharedWithoutFPURegsStub</span>
                     a0: <span class="k">b.al</span>	<span class="nb">-&gt;30</span>
                         <span class="c">;; slow path check null (nsm) operation</span>
                     a4: <span class="k">bl</span>	<span class="nb">Stub::NullErrorSharedWithoutFPURegsStub</span>
  8.01% new _GrowableList._withData (libapp.so)
  7.63% new _GrowableList (libapp.so)
  4.96% _GrowableList._allocateData (libapp.so)
  3.66% unknown ([kernel.kallsyms])
  ..(run with -v to disassemble all hot methods in libapp.so)..
</code></pre></div>

Now it should be visible in the output that `allocateFixedArray` does not
actually contain *any array allocation*, it got eliminated (sunk) by the
compiler, so our benchmark seems to be comparing performance of an empty
`while (N-- > 0);` loop to the performance a loop that actually does some
array allocations.

The empty loop however is far from trivial. It seems to contain two sources of
overhead by itself:

* Variable `numIterations` seems to be  unboxed and reboxed on each loop iteration, as evident from the following sequence of instructions that implements `numIterations--`:
    <div class="highlighter-rouge language-console highlight"><pre><code><span class="c">;; CheckNull:10(v3, NoSuchMethodError) T{int}</span>
18: <span class="k">cmp</span> <span class="nv">x2</span>, <span class="nv">null</span>
1c: <span class="k">b.eq</span> <span class="nb">-&gt;68</span>
    <span class="c">;; v26 &lt;- UnboxInt64(v3 T{int}) T{int}</span>
20: <span class="k">asr</span> <span class="nv">x3</span>, <span class="nv">x2</span>, <span class="mi">#1</span>
24: <span class="k">tbz</span> <span class="nv">w2</span>, <span class="mi">#0</span>, <span class="nb">-&gt;2c</span>
28: <span class="k">ldur</span> <span class="nv">x3</span>, [<span class="nv">x2</span>, <span class="mi">#7</span>]
    <span class="c">;; v6 &lt;- BinaryInt64Op(- [tr], v26 T{int}, v32) T{int}</span>
2c: <span class="k">sub</span> <span class="nv">x2</span>, <span class="nv">x3</span>, <span class="mi">#1</span>
    <span class="c">&lt;...&gt;</span>
    <span class="c">;; v30 &lt;- BoxInt64(v6) T{int}</span>
38: <span class="k">adds</span> <span class="nv">x0</span>, <span class="nv">x2</span>, <span class="nv">x2</span>
3c: <span class="k">b.vc</span> <span class="nb">-&gt;48</span>
40: <span class="k">bl</span> <span class="nb">Stub::AllocateMintSharedWithoutFPURegsStub</span>
44: <span class="k">stur</span> <span class="nv">x2</span>, [<span class="nv">x0</span>, <span class="mi">#7</span>]</code></pre></div>
* Loop header contains a `CheckStackOverflow` instruction which performs a memory load and a comparison on each loop iteration.
    <div class="highlighter-rouge language-console highlight"><pre><code><span class="c">;; CheckStackOverflow:30(stack=0, loop=1)</span>
24: <span class="k">ldr</span> <span class="nv">x16</span>, [<span class="nv">thr</span>, <span class="mi">#64</span>]
28: <span class="k">cmp</span> <span class="nv">sp</span>, <span class="nv">x16</span>
2c: <span class="k">b.ls</span> <span class="nb">-&gt;9c</span></code></pre></div>

For accurate microbenchmarking we should certainly make an effort to reduce
overhead of measured loop to bare minimum.

### Preventing boxing of `numIterations`

```dart
void _$measuredLoop$allocateGrowableArray(int numIterations) {
  while (numIterations-- > 0) {
    lib.allocateGrowableArray();
  }
}
```

Why is `numIterations` kept boxed by the compiler? There are multiple factors at play here. Most importantly compiler is simply unable to prove that `numIterations` is not `null` on entry to the function, which happens because we use a tear-off of a measured loop method to invoke it. *TFA* (*type flow analysis*, our global type propagation algorithm) does not attempt to infer precise type information for parameters of closures. If our code was structured using classes, for example: <span class="sidenote">If we were running in sound non-nullable by default (NNBD) mode then compiler would also be able to rely on the fact that <code>numIterations</code> can never be <code>null</code>. This illustrates one of the benefits of NNBD: giving compiler more information to work with.</span>

```dart
abstract class MeasuredLoop {
  void run(int numIterations);
}

class Loop$allocateGrowableArray extends MeasuredLoop {
  void run(int numIterations) =>
      _$measuredLoop$allocateGrowableArray(numIterations);
}

void main() {
  await benchmark_runner.runBenchmarks(const {
    // Use class instead of tearing off _$measuredLoop$allocateGrowableArray
    'allocateGrowableArray': Loop$allocateGrowableArray(),
  });
}
```

Then compiler would be able to infer that `numIterations` is never nullable, and not only unbox `numIterations` locally inside `run` and `_$measuredLoop$...` but even alter calling conventions of these two functions to pass parameter
around without boxing.

The reason why this works for methods and does not (yet) work for closures is because a statically typed method call gives compiler more information about
potential callees than a statically typed closure call.

```dart
class Loop$allocateGrowableArray extends MeasuredLoop {
  void run(int numIterations) {
    // Can only be reached from a call-site where
    // static type of a receiver is either [dynamic] or
    // related to [Loop$allocateGrowableArray].
  }
}

MeasuredLoop loop;
loop.run(...);  // Can invoke only overrides of [MeasuredLoop.run].

// ---------------------------------------------------------

var g = (int numIterations) {
  // Can be reached from any closure call-site with a compatible
  // function type and invocation signature.
};

void Function(int) f;
f(...);  // Can reach any compatible closure in the program.
```

Right now TFA does a very conservative approximation assuming that any closure
could be invoked from anywhere else. This certainly could be improved:
for example, TFA could use static type information to narrow potential
call-sites for each closure. This can be taken even further - TFA could
attempt to track the flow of closures through the program and try to
establish which call-sites it could reach, but that's a more sophisticated
analysis.

Given that TFA can't infer `numIterations` as never containing `null` we
might want to help it by adding an explicit check at the start of the
measured loop wrapper.

```dart
void _$measuredLoop$allocateGrowableArray(int numIterations) {
  if (numIterations == null) throw 'Unexpected null!';
  while (numIterations-- > 0) {
    lib.allocateGrowableArray();
  }
}
```

Unfortunately this does not help: even though compiler infers that `numIterations` is never `null` inside the loop it still does not unbox it, because its unboxing algorithm is overly conservative around `int` typed variables. Current set of heuristics only unboxes integer variables if all reaching values are either boxing operations or constants. Which is probably a bug that needs to be fixed, but in the meantime we could simply satisfy this requirement: <span class="sidenote">I am allowing myself a slight imprecision when talking about unboxing here. Compiler does not actually unbox <em>variables</em>, because it operates on SSA-form which does not contain any operations with variables anymore. It would be more precise to talk about unboxing <em>phis</em>, but I did not want to confuse readers without compiler background too much.</span>

```dart
void _$measuredLoop$allocateGrowableArray(int numIterations) {
  // n will be unboxed because it is either
  //     Box(Unbox(numIterations) + 0) or Box(Unbox(n) - 1)
  var n = numIterations + 0;
  while (n-- > 0) {
    lib.allocateGrowableArray();
  }
}
```

### Eliminating `CheckStackOverflow`

`CheckStackOverflow` instructions inserted by the compiler have dual purpose: they check for stack overflow (as their name implies), but also serve as interruption points, allowing VM to cleanly interrupt a thread executing Dart code. This mechanism can, for example, be used by the GC to park mutator thread at a safepoint. `CheckStackOverflow`'s are rather fast: they consist of a memory load which usually hits the CPU cache and a compare-and-branch which is almost never taken. However they can still have a visible cost in very tight loops.

As an experiment I have changed the VM to completely eliminate `CheckStackOverflow` instructions from functions marked with `@pragma('vm:no-interrupts')`.

With a `CheckStackOverflow` instruction empty loop takes `3.56 ns/iteration` per iteration and without it empty loop takes `1.78 ns/iteration` which is basically twice as fast.

The final shape of an empty measuring loop is:

<div class="highlighter-rouge language-console highlight"><pre><code><span class="c">    ;; v9 <- BinaryInt64Op(- [tr], v6 T{int}, v36) T{int}</span>
24: <span class="k">sub</span>    <span class="nv">x0</span>, <span class="nv">x1</span>, <span class="mi">#1</span>
<span class="c">    ;; Branch if RelationalOp(>, v6 T{int}, v34) T{bool} goto (3, 5)</span>
28: <span class="k">cmp</span>    <span class="nv">x1</span>, <span class="mi">#0</span>
2c: <span class="k">b.le</span>   <span class="nb">-&gt;38</span>
<span class="c">    ;; ParallelMove r1 <- r0 goto:32 B4</span>
30: <span class="k">mov</span>    <span class="nv">x1</span>, <span class="nv">x0</span>
34: <span class="k">b.al</span>   <span class="nb">-&gt;24</span>
</code></pre></div>

### Preventing compiler from optimizing computations out

The final step is to fix the benchmark to prevent compiler from optimizing
out our computation. The core idea is to change each benchmark to
return a value it produces and to make measured loops consume returned values:

```dart
// ubench/lib/main.dart

@benchmark
Object allocateFixedArray() {
  return List.filled(N, null, growable: false);
}

// ubench/lib/main.benchmark.dart
@pragma('vm:never-inline')
@pragma('vm:no-interrupts')
void _$measuredLoop$allocateFixedArray(int numIterations) {
  // ...
  while (n-- > 0) {
    final result = lib.allocateFixedArray();
    // Call a special intrinsic from dart:_internal which keeps
    // the value alive and prevents it from being optimized out.
    // However does not result in any actual calls being produced.
    benchmark_runner.reachabilityFence(result);
  }
}
```

## Final benchmark results

With benchmark harness *and* benchmark itself fixed to prevent compiler from
optimizing away list allocation we are getting the following results

```
Results for lib/main.benchmark.dart
allocateFixedArray: 131.607 (±0.845) ns/iteration (fastest)
allocateGrowableArray: 177.443 (±1.603) ns/iteration (1.3 times as slow)

Hot methods when running allocateFixedArray:
 77.98% Stub::AllocateArrayStub (libapp.so)
  6.19% measured loop for allocateFixedArray (libapp.so)
  5.21% unknown ([kernel.kallsyms])
  1.16% pthread_mutex_lock (libc.so)
  1.16% pthread_mutex_unlock (libc.so)

Hot methods when running allocateGrowableArray:
 53.13% Stub::AllocateArrayStub (libapp.so)
 11.53% new _GrowableList._withData (libapp.so)
  9.35% new _GrowableList (libapp.so)
  8.15% measured loop for allocateGrowableArray (libapp.so)
  6.23% _GrowableList._allocateData (libapp.so)
  3.92% unknown ([kernel.kallsyms])
```

So allocating growable list with 32 element takes ~30% more time compared to
allocating a fixed length list with 32 elements which is much more reasonable
result than what we were getting with our initial benchmarks.

This also makes sense: growable array is just an object which contains inside
a fixed length array so allocating a growable array is a bit slower than
allocating a fixed length array because you need to allocate and initialize more
memory and you need to jump through more hoops to get there: in `allocateFixedArray`
most of the time is spent in a stub (a piece of handwritten machine code)
which allocates the array, in `allocateGrowableArray` there are multiple
functions involved in doing the job.

## Final remarks on benchmarking

In general I have chosen to neglect in this post some of the hardest problems associated with microbenchmarking : for example, I decided to ignore JIT altogether and focus specifically on AOT. Benchmarking JITs is really hard because they behave like living organisms and show wild fluctuations in performance even after long warmup (see for example <a href="https://soft-dev.org/pubs/html/barrett_bolz-tereick_killick_mount_tratt__virtual_machine_warmup_blows_hot_and_cold_v6/">Virtual Machine Warmup Blows Hot and Cold</a> paper). I also decided to focus on a simplistic <em>average cost of operation</em> metric, which might hide some of the important but not constantly present overheads. Array allocation is actually a great example: it might be rather cheap in general, but every so often it might trigger a GC - the cost of which will be proportional to the amount of live data, which will probably close to 0 in microbenchmark. Averaging over thousands and thousands of operations would completely erase the cost of the GC, however in the real application GCs like this might matter because they might cause a missed frame.

## Next Part

In the Part 2 of the series I am going to use benchmarking harness CLI, I have
just implemented to answer more performance questions I have gotten on Twitter,
for example:

* how changing field initializer from `[]` to `List.filled(0, null)` can improve
performance of your code;
* performance characteristics of `async` syntax sugar;
* what happens when you call a closure through a dynamically typed variable;

Till next time.

<p style="background: rgba(204, 0, 0, .2); padding: .5em;">I am always available
to help you with Dart related performance questions and concerns. Do not hesitate
to reach out to me by mail or through other channels like Twitter.</p>
