(function() {
  var CONFIG = "MathJax.Hub.Config({"
             + "  tex2jax: {"
             + "    inlineMath: [['\\\\(','\\\\)']],"
             + "    skipTags: ['script','noscript','style','textarea'], displayAlign: 'center'"
             + "  },"
             + "  displayAlign: 'center'"
             + "});";

  var config = document.createElement("script");
  config.type = "text/x-mathjax-config";
  config.appendChild(document.createTextNode(CONFIG));
  document.body.appendChild(config);

  var script = document.createElement("script");
  script.type = "text/javascript";
  script.src = "https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-MML-AM_CHTML";
  script.async = true;
  document.body.appendChild(script);
})();
