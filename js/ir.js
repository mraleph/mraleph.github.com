(function () {
  function row(a, b, k) {
    return '<tr><td style="border-right: 1px solid #ccc;">' + a + '</td><td class="' + k + '">' + b + ' </td></tr>';
  }

  function span(k, v) {
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

  var nodes = document.querySelectorAll("pre.hydrogen");
  for (var i = 0; i < nodes.length; i++) {
    var node = nodes[i];
    var lines = node.innerText.split("\n").map(function (line) {
      var m = line.match("^(.*?)(//.*?)$");
      var comment = "";
      if (m !== null) {
        line = m[1];
        comment = "<em>" + m[2] + "</em>";
      }
      m = line.match(/^([Bidstv]?\d+)?(\s+([-\w]+)?(.*))?$/);
      if (m === null) {
        return row("", "");
      }

      var val = m[1];
      var isLir = false;
      if (typeof val === "undefined") {
        val = "";
      } else {
        isLir = /^\d+$/.test(val);
        val = span((val[0] === "B") ? "ir-ref boldy" : "ir-ref", val);
      }

      return row(val, span("boldy", m[3] || "") + hi(m[4] || "") + comment, isLir ? "lir" : "");
    });

    node.innerHTML = '<table style="border-spacing: 0px; border-collapse: collapse;">' + lines.join('') + '</table>';
    node.classList.add('highlight');
    node.style['border-top'] = node.style['border-bottom'] = '1px solid #ccc';
  }
})();
