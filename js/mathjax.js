(function() {
  var CONFIG = "MathJax.Hub.Config({"
             + "  tex2jax: {"
             + "    inlineMath: [['$','$'], ['\\\\(','\\\\)']],"
             + "    skipTags: ['script','noscript','style','textarea']"
             + "  }"
             + "});";

  var config = document.createElement("script");
  config.type = "text/x-mathjax-config";
  config.appendChild(document.createTextNode(CONFIG));
  document.body.appendChild(config);

  var script = document.createElement("script");
  script.type = "text/javascript";
  script.src = "https://c328740.ssl.cf1.rackcdn.com/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML";
  document.body.appendChild(script);
})();
