---
layout: blogpost
title: (Pre)release IRHydra 2.0
date: 2014-01-28
---

<center style="margin-top: 5px; margin-bottom: 5px;"><iframe width="420" height="315" src="https://www.youtube.com/embed/pycQWDuCBN8" frameborder="0" allowfullscreen="">
</iframe><br/><a href="http://alpha.irhydra.googlecode.com/git/build/index.html"><span style="font-size: 1.3em">deployed IRHydra 2.0</span></a></center>

It's been almost a year since I [released IRHydra](http://mrale.ph/blog/2013/02/17/release-the-irhydra.html), a tool that can visualize V8 and Dart VM compilation artifacts, help you navigate them and grok what JIT compiler does to your code.

I think it is only fair that as a birthday gift 1 year old IRHydra will get some exciting new features.

New UI
------

<div style="text-align: center;"><img src="/images/2014-01-28/main.png"/></div>

Overall I tried to simplify UI for the common case thanks to some good suggestions from [Matt Pardee](https://twitter.com/matt_pardee) and [Paul Fryzel](https://twitter.com/paulfryzel).

<div style="text-align: center;"><img src="/images/2014-01-28/deopt-colors.png"/></div>

Colors of deoptimization markers and links now tries to communicate *importance* of a particular type of the deoptimization (eager, lazy, soft). Methods in the method list are highlighted with the color of their worst deoptimization.

<div style="text-align: center;"><img src="/images/2014-01-28/deopt-hover.png"/></div>

Detailed information about the deoptimization is just a hover away.

<div style="text-align: center;"><img src="/images/2014-01-28/deopt-source.png"/></div>

What's more important: the same information is attached to the source so that you don't have to read all IR trying to figure out which place in the program `CheckMaps` came from. This display is inlining sensitive: it will place deoptimization marker inside the right inlined function so that you can be completely sure which code path it originated from.

<div style="text-align: center;"><img src="/images/2014-01-28/graph-coloring.png"/></div>

Graph view now applies semantic coloring:

* blocks that are dominated by unconditional deoptimization will be almost transparent to hint the fact that their contents are irrelevant;
* blocks that contain unconditional deoptimization will have purple border (matching the color used for soft deoptimizations);
* blocks containing `changes[*]` instructions whill have dashed-red border to attract attention to them, because such flags inhibit most optimizations.

Inner fill for the blocks is still selected from a [Brewer palette](http://mkweb.bcgsc.ca/brewer/) based on their loop nesting. Dart VM mode used to have `ll_prof` support to color blocks depending on amount of ticks falling into them, but I temporarily disabled this feature for now.

<div style="text-align: center;"><img src="/images/2014-01-28/searching.png"/></div>

Method filtering now supports searching for a specific text inside method sources (if available) just prefix the filter with `src:`.

Old features
------------

Just like previous version new IRHydra supports:

* crossreferencing of IR names on hover and navigation between them;
* displaying uses of the IR name when you click on its definition (though UI is somewhat borked);
* IR opcode descriptions.

One currently disabled feature as I already mentioned above is `ll_prof` support.

Technology stack
----------------

IRHydra 2.0 UI was rewritten to use Polymer.dart. Uses bits of Bootstrap for styling and components like tooltips and popovers. Some colors taken from Flat UI palette.

Known issues and limitations
----------------------------

Requires applying a [patch](https://code.google.com/p/irhydra/source/browse/patches/v8.r18822.patch?name=polymerized) on top of V8 to work.

Does not work in Firefox (neither Stable nor Nightly), but works in Chrome Dev and Safari.

Future plans
------------

I have a lot of ideas how to enhance source view to surface interesting information (e.g. what was LICMed, what was DCEd, which checks are still inside the loops etc.) even more prominently. However my priority right now is making sure that all old features work and the code is in the nice state (right now it is not) for merging into the main brunch.

Contributions are always welcome. Reach out to me if you are interested even if it is just UI/CSS tweaks. Me and CSS are not the best friends anyways :-)

Have fun digging into IRs!