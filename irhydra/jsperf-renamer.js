// This script tries to hook into Benchmark.js used by jsPerf and give all
// functions it generates for benchmarking meaningful names, so it would
// be easier to use IRHydra with them.
(function() {
  // First find a <script>-tag that contains definitions of test cases.
  // Test cases are defined using API calls that look like:
  //
  //         ui.add('name', 'source')
  //
  var scripts = document.querySelectorAll("script");
  var cases = [];
  for (var i = 0; i < scripts.length; i++) {
    var script = scripts[i].text;
    if (script.indexOf("ui.add") >= 0 && script.indexOf("PLEASEIGNOREME") === -1) {  // Avoid finding this script tag.
      // Compile and invoke script with fake ui object that will collect
      // all test cases.
      new Function("ui", "Benchmark", script)({  // ui
        browserscope: { },
        add: function (name, opts) {
          var src = typeof opts === 'string' ? opts : opts.fn;
          cases.push({
            // Cleanup case name, we will use it as a function name in dynamically
            // generated JS source.
            name: 'Benchmark$' + name.replace(/[^\w]/g, '_'),

            // Wrap case body just like Benchmark.js wraps it. This will allow to avoid
            // some false-positives when one test case is a prefix of another.
            // (but it does not eliminate all false positives).
            src: "{" + typeof src.trim() + "\n}"
          });
          return this;
        }
      }, {  // Benchmark
        prototype: {}
      });
      break;
    }
  }

  // Benchmark.js injects <script>-tags. Replace createElement to hook into that
  // and dynamically rewrite compiled code.
  var createElement = document.createElement;
  document.createElement = function (type) {
    // First create element using normal document.createElement.
    var el = createElement.apply(this, arguments);

    if (type === "script") {
      // This is a dynamically generated <script>-tag. Source will be added
      // with appendNode(document.createTextNode(...)). Replace appendChild
      // to catch and rewrite it.
      var appendChild = el.appendChild;
      el.appendChild = function (child) {
        var src = child.wholeText;

        // Try matching a case to figure out if this is the function compiled
        // to perform a single measured run of benchmark case.
        for (var i = 0; i < cases.length; i++) {
          if (src.indexOf(cases[i].src) >= 0) {  // Looks like it is one of the cases.
            var name = cases[i].name;
            // Rewrite anonymous function into a named one. Only rename the first occurrence. 
            child = document.createTextNode(src.replace(/=function\(/, '=function ' + name + ' ('));
            break;
          }
        }

        // Invoke normal appendChild with a potentially rewritten child.
        return appendChild.apply(this, arguments);
      };
    }

    // Return created element.
    return el;
  };
})();
