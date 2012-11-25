---
layout: blogpost
title: Shaky diagramming
date: 2012-11-25
---

Quite a few asked me what application I use to draw shaky diagrams for my blog posts and slides. And the answer is really quite obvious: I am using the browser running a little bit of Dart &#x263A;

Browser is my new Delphi
-------------------------

These days anybody hardly ever knows what [Delphi](http://en.wikipedia.org/wiki/Embarcadero_Delphi) is but back when I was surviving through the the school it was quite huge. If a school had modern enough computers then those would be no doubt running at least Delphi 3 (which was probably pirated). Amount of software being cranked out on Delphi was also quite astounding.

No idea how this had happened but probably it can be partially explained by widespread use of Pascal for teaching. I can hardly imagine how evil a teacher should be to take children's innocence away by inducting them into intricacies of `lpsz` and `BEGIN_EVENT_MAP`. On the other hand Pascal is a powerful yet simple and motherly programming language that always had bounds checking enabled by default thus saving many young souls. So when Delphi appeared it found its audience: myriads of graduates quite experienced in writing Pascal. That's I guess how a feedback loop was closed and continued to exist for some time. Object Pascal plus over 9000 of components ready to be drag'n'droped to your TForm secured an instant win.

So back in the late 90s Delphi suddenly became my tool of choice for literally everything. I need to compute something and plot a graph? I launch Delphi. I need UI to populate some local DB? Delphi! I want to try and implement a [MUD](http://en.wikipedia.org/wiki/MUD) with a friend... What a luck, I still have Delphi opened since last night!

However somewhere in 00s Delphi disappeared from my life and did not come back ever since.

<small>[<a href="http://en.wikipedia.org/wiki/List_of_programming_languages_by_type#Wirth_languages">Wirth languages</a> however did come back and I had a lot of fun at <a href="http://www.excelsior-usa.com/">Excelsior</a> writing mostly Modula-2 and <a href="http://en.wikipedia.org/wiki/Oberon-2_(programming_language)">Oberon-2</a>.]</small>

Surprisingly in my life it was largely replaced by a tool that was never intended to become an IDE replacement. These days if I suddenly need to create an interactive application that layouts and lets me explore a [CFG](http://en.wikipedia.org/wiki/Control_flow_graph) produced by an optimizing compiler I just launch an editor, throw together some HTML/CSS/JavaScript, start my browser and it will do the job.

Drawing shaky diagrams
----------------------

When I first decided that all diagrams in my posts about V8 should be "shaky" I started to draw them [by hand](http://s3.mrale.ph/images/point-structure-c.png) on my Wacom tablet. But I am actually very-very-very bad at drawing (I use it mostly to relief stress via doodling) and each diagram was consuming far too much time. Finally when my tablet suddenly died I decided to explore a programmatic solution.

First of all I realized that I do not want to waste my time writing diagramming GUI. Creating, resizing, undoing, changing colors, moving, redoing... It's a pit full of pain and misery! I just wanted a tool that would take a simple diagram description and give back a picture. How should description look like? I am a compiler guy so it should obviously be a text... Something like this:

    +----+  +----+
    |V8  |  |    |
    |   *+--+> JS|
    +----+  +----+

and it should turn into

<img src="/images/2012-11-25/example.png"/>

Once output format was decided I quickly hacked together a simple parser and was left with just two problems on my hands: *shaky lines* and *saving canvas to file*.

Shaky lines
-----------

When I starting thinking about mathematical models for my shaky nervous hands I realized that HTML5 Canvas API already has a good approximation: [cubic B&eacute;zier curves](http://en.wikipedia.org/wiki/B%C3%A9zier_curve#Cubic_B.C3.A9zier_curves). These curves are defined by their *start*, *end* plus two additional *waypoints* (usually called *control points*). Skipping fine mathematical formalism (read Wikipedia if you are curious) one can simply think that B&eacute;zier curve is a path of a point that was initially attracted by the first waypoint, but before reaching it slowly decided that the second waypoint is way more interesting, then again changed its mind and arrived to the last point (curve's end). To get a feel I recommend playing with a [great interactive demo](http://blogs.sitepointstatic.com/examples/tech/canvas-curves/bezier-curve.html) by Craig Buckler.

So how do I get shaky line out of a B&eacute;zier curve? Quite easy actually: if I pick two random waypoints on the opposite sides of the straight line connecting given start and end then B&eacute;zier curve will "jerk" between those two points but overall look like a straight line to the human eye if those points are close enough to the initial straight line.

Here is a small function in Dart that implements this idea:

<small>[Why Dart? Because I like to eat my own dog food.]</small>

{% highlight dart %}
import 'dart:math' as Math;

final random = new Math.Random();

shakyLine(x0, y0, x1, y1) {
  // Let $v = (d_x, d_y)$ be a vector between points $P_0 = (x_0, y_0)$ and $P_1 = (x_1, y_1)$.
  var dx = x1 - x0;
  var dy = y1 - y0;

  // Let $l$ be the length of $v$.
  var l = Math.sqrt(dx * dx + dy * dy);

  // Now we need to pick two random points that are placed
  // on different sides of the line that passes through
  // $P_1$ and $P_2$ and not very far from it if length of
  // $P_1 P_2$ is small.
  var k = Math.sqrt(l) / 1.5;
  var k1 = random.nextDouble();
  var k2 = random.nextDouble();
  var l3 = random.nextDouble() * k;
  var l4 = random.nextDouble() * k;

  // Point $P_3$: pick a random point on the line between $P_0$ and $P_1$,
  // then shift it by vector $\frac{l_3}{l} (d_y, -d_x)$ which is a line's normal.
  var x3 = x0 + dx * k1 + dy/l * l3;
  var y3 = y0 + dy * k1 - dx/l * l3;

  // Point $P_3$: pick a random point on the line between $P_0$ and $P_1$,
  // then shift it by vector $\frac{l_4}{l} (-d_y, d_x)$ which also is a line's normal
  // but points into opposite direction from the one we used for $P_3$.
  var x4 = x0 + dx * k2 - dy/l * l4;
  var y4 = y0 + dy * k2 + dx/l * l4;

  // Draw a bezier curve through points $P_0$, $P_3$, $P_4$, $P_1$.
  // Selection of $P_3$ and $P_4$ makes line "jerk" a little
  // between them but otherwise it will be mostly straight thus
  // creating illusion of being hand drawn.
  ctx.moveTo(x0, y0);
  ctx.bezierCurveTo(x3, y3, x4, y4, x1, y1);
}
{% endhighlight %}

The most mysterious part here is probably the coefficient `k`. Here is the idea behind it: control points can be further away for long lines (tired hand shakes more wildly) and closer for shorter lines (hand is not tired, shakes less). I tries different functions and coefficients and arrived to this one.

Saving canvas contents to a file
--------------------------------

Initially I was very puzzled about this and even thought about writing a server side picture writer in node.js but then I discovered that canvas can be converted to [Data URI](http://en.wikipedia.org/wiki/Data_URI_scheme) with [toDataURL](http://docs.webplatform.org/wiki/canvas/methods/toDataURL) method:

{% highlight dart %}
html.query("#save").on.click.add((e) {
  new html.AnchorElement()
          ..href = html.query("#canvas").toDataURL("image/png")
          ..attributes['download'] = html.query("#name").value
          ..click();
});
{% endhighlight %}

Happy End
---------

It took me maybe an hour to hack bits and pieces of this together and after that I was just drawing diagrams and writing actually important stuff. Browser kinda saves the day again...

You can play with the tool [here](https://moe-js.googlecode.com/git/talks/jsconfeu2012/tools/shaky/shaky.html).

<script type="text/x-mathjax-config">
  MathJax.Hub.Config({
    tex2jax: {
      inlineMath: [['$','$'], ['\\(','\\)']],
      skipTags: ["script","noscript","style","textarea"]
    }
  });
</script>
<script type="text/javascript"
  src="https://c328740.ssl.cf1.rackcdn.com/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML">
</script>
