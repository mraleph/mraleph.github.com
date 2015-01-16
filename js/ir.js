window.addEventListener("load", function () {
  function row(a, b, k) {
    if (typeof k === 'undefined') k = "";
    if (loop > 0) k += (" loop-" + loop);
    return '<tr><td style="border-right: 1px solid #ccc;">' + a + '</td><td class="' + k + '">' + b + ' </td></tr>';
  }

  function span(k, v) {
    if (k === '') return v;
    return '<span class="' + k + '">' + v + '</span>';
  }

  var patterns = [
    [ /^0x[a-f0-9]+/, "mh" ],
    [ /^\d+/, "mi" ],
    [ /^".*?"/, "s1" ],
    [ /^[idstv]\d+/, "ir-ref" ],
    [ /^B\d+/, "ir-ref boldy" ],
    [ /^;;.*$/, "c1" ]
  ];

  function hi(x) {
    var result = [];
    outer: while (x.length > 0) {
      for (var i = 0; i < patterns.length; i++) {
        var m = x.match(patterns[i][0]);
        if (m !== null) {
          result.push(span(patterns[i][1], m[0]));
          x = x.substring(m[0].length);
          continue outer;
        }
      }
      result.push(x[0]);
      x = x.substring(1);
    }
    return result.join('');
  }

  function markerClass(state) {
    if (state === "-") {
      return "";
    } else if (state === "^") {
      return "src-range-point";
    } else {
      return "src-range-transparent";
    }
  }

  function split(str, markers) {
    var result = [];
    var j = 0;
    outer: for (var i = 0; i < str.length; i++) {
      if (i >= markers.length) {
        result.push(span(markerClass(" "), str.substring(i)));
        break;
      }

      var state = markers[i];
      for (var j = (i + 1); j < str.length; j++) {
        if (markers[j] != state) {
          break;
        }
      }

      result.push(span(markerClass(state), str.substring(i, j)));
      i = j - 1;
    }

    return prettyPrintOne(span("src-range", result.join('')));
  }

  var nodes = document.querySelectorAll("pre.hydrogen");
  for (var i = 0; i < nodes.length; i++) {
    var node = nodes[i];
    var data = (node.innerText || node.textContent).split("\n");
    var lines = [];
    var loop = 0;
    for (var idx = 0; idx < data.length; idx++) {
      var line = data[idx];
      var m = line.match(/^!(\d+)$/);
      if (m !== null) {
        loop = +m[1];
        continue;
      }

      var m = line.match(/^\s*##(.+)$/);
      if (m !== null) {
        var srcLine = m[1];
        var markerLine = data[++idx].match(/^\s*##(.+)$/)[1];
        lines.push(row("", split(srcLine, markerLine)));
        continue;
      }

      var m = line.match(/^(.*?)(\/\/.*?)$/);
      var comment = "";
      if (m !== null) {
        line = m[1];
        comment = span("c1", m[2]);
      }
      m = line.match(/^([Bidstv]?\d+)?(\s+([-\w]+)?(.*))?$/);
      if (m === null) {
        lines.push(row("", ""));
        continue;
      }

      var val = m[1];
      var isLir = false;
      if (typeof val === "undefined") {
        val = "";
      } else {
        isLir = /^\d+$/.test(val);
        val = span((val[0] === "B") ? "ir-ref boldy" : "ir-ref", val);
      }

      lines.push(row(val, span("boldy", m[3] || "") + hi(m[4] || "") + comment, isLir ? "lir" : ""));
    }

    node.innerHTML = '<table style="border-spacing: 0px; border-collapse: collapse;">' + lines.join('') + '</table>';
    node.classList.add('highlight');
    node.style['border-top'] = node.style['border-bottom'] = '1px solid #ccc';
  }
});
