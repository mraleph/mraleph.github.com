(function() {
  MathJax = {
    options: {
      skipHtmlTags: {
        '[-]': ['code', 'pre'],
      }
    }
  };

  var script = document.createElement("script");
  script.type = "text/javascript";
  script.src = "https://cdn.jsdelivr.net/npm/mathjax@4/tex-mml-chtml.js";
  script.async = true;
  document.body.appendChild(script);
})();
