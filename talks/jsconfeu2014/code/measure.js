
load("jsperf.js");

Benchmark.prototype.setup = function () {
  var vs = [];
  if (NAIVE_MEASURE) { global.vs = vs; }
  for (var i = 0; i < 10000; i++) vs.push(new Vector(i + 0.5, -i + 0.5));
  var result;
};

Benchmark.prototype.teardown = function () {
  var expected = 4999000100000000;
  if (result !== expected) {
    throw new Error("expected " + expected + " got " + result);
  }
}

measure({
  'sum': function () {
    result = lensum(vs, 0, vs.length);
  }
});