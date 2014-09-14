//
// Benchmark.js wrapper that limits amounts of samples to minimize the size
// of produced hydrogen.cfg/code.asm dumps.
//

load("lodash.js");
load("benchmark.js");

var NAIVE_MEASURE = false;
var LIMIT_RUNS = false;

if (LIMIT_RUNS) {
  // Limit number of runs
  // Benchmark.options.maxTime = 0;
  // Benchmark.options.minSamples = 2;
}

function time(f, N) {
   var start = Date.now();
   for (var i = 0; i < N; i++) f();
   var end = Date.now();
   return (end - start);
}
time(function () { }, 1)
time(function () { }, 1)

function measure(cases) {
  if (NAIVE_MEASURE) {
    Object.keys(cases).forEach(function (name) {
      Benchmark.prototype.setup();
      time(cases[name], 10000);
      print(name + ": " + time(cases[name], 100000));
    });
    return;
  }

  var suite = new Benchmark.Suite();

  Object.keys(cases).forEach(function (name) {
    suite.add(name, cases[name]);
  });


  suite
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
}