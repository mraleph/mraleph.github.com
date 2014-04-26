---
layout: blogpost
title: V8 Resources
date: 2014-04-20
---

<style>
  sup.v8 {
    color: #4e8aec;
    font-weight: bold;
  }

  a {
    color: #4e8aec;
  }

  li {
    margin: 0.2em 0px;
  }
</style>

* Test
{:toc}

## Practical / optimization

### Talks

* Understanding V8 (me, nodecamp.eu 2011) [\[slides\]](http://s3.mrale.ph/nodecamp.eu/#1)
* V8 Performance Tuning Tricks ([+Daniel Clifford](https://plus.google.com/111909581069462963574), GDD2011 Berlin) [\[slides\]](https://mkw.st/p/gdd11-berlin-v8-performance-tuning-tricks/#1)
* Console to Chrome ([+Lilli Thompson](https://plus.google.com/111647958621817995641), GDC 2012) [\[slides\]](http://console-to-chrome.appspot.com/#8) [\[video\]](http://www.youtube.com/watch?v=XAqIpGU8ZZk#t=9m0s)
* Breaking the JavaScript Speed Barrier with V8 ([+Daniel Clifford](https://plus.google.com/111909581069462963574), Google I/O 2012) [\[slides\]](http://v8-io12.appspot.com/index.html) [\[video\]](http://www.youtube.com/watch?v=UJPdhx5zTaw)
* The Footprint of Performance [@Michael Starzinger](https://twitter.com/starzi) describes memory implications of various programming patterns. [\[JSConf EU 2012 video\]](http://www.youtube.com/watch?v=ZhshEZIV2F4) [\[NodeDublin 2012 video\]](https://www.youtube.com/watch?v=cWdtLAsaDpw)
* [Building High-Performing JavaScript for Modern Engines \[video\]](http://channel9.msdn.com/Events/Build/2012/4-000): performance recommendations from Microsoft's JavaScript team (tailored to Chakra but many things still apply to V8).
* [Accelerating Oz with V8 \[video\]](http://www.youtube.com/watch?v=VhpdsjBUS3g) by [+John McCutchan](https://plus.google.com/+JohnMcCutchan) (Google I/O 2013) walks through the experience of eliminating junk from [Find Your Way To OZ](http://www.chromeexperiments.com/detail/find-your-way-to-oz/) Chrome experiment.
* [A Trip Down Memory Lane with Gmail and DevTools \[video\]](http://www.youtube.com/watch?v=x9Jlu_h_Lyw) by [+John McCutchan](https://plus.google.com/+JohnMcCutchan) and [+Loreena Lee](https://plus.google.com/+LoreenaLee) (Google I/O 2013) a success story of eliminating memory leaks in GMail with Chrome Dev Tools.
* Doubt Everything a talk about common microbenchmarking pitfalls by me at LXJS 2013 [\[slides\]](http://mrale.ph/talks/lxjs2013) [\[video\]](http://www.youtube.com/watch?v=65-RbBwZQdU)

### Articles

* [Optimizing for V8](http://floitsch.blogspot.dk/2012/03/optimizing-for-v8-introduction.html), series of blog posts from [+Florian Loitsch](https://plus.google.com/103716596068416580695), based on his experience writing dart2js compiler
* [Performance tips for JavaScript in V8](http://www.html5rocks.com/en/tutorials/speed/v8/) by [+Chris Wilson](https://plus.sandbox.google.com/106422711035746240826/posts)
* [Writing Fast, Memory-Efficient JavaScript](http://coding.smashingmagazine.com/2012/11/05/writing-fast-memory-efficient-javascript/) by [Addy Osmani](https://twitter.com/addyosmani)

## General

<small>(old talks might contain outdated information)</small>

### Talks

* V8: High Performance JavaScript Engine in Google Chrome ([+Kevin Millikin](https://plus.google.com/118332431854651588625), GDD 2008 London) [\[video\]](http://www.youtube.com/watch?v=lZnaaUoHPhs) &nbsp;
* V8 Internals ([+Mads Ager](https://plus.google.com/105218366515825183046), Google I/O 2009)&nbsp;[\[video\]](http://www.youtube.com/watch?v=FrufJFBSoQY)
* Crankshaft: Turbocharging the Next Generation of Web ([+Kasper Lund](https://plus.google.com/100258330325630692559), YOW 2011) [\[video\]](http://yow.eventer.com/events/1004/talks/1017) [\[slides\]](http://gotocon.com/dl/goto-aarhus-2011/slides/KasperLund_CrankshaftTurbochargingTheNextGenerationOfWebApplications.pdf)
* [Web Languages and VMs: Fast Code is Always in Fashion.](http://www.youtube.com/watch?v=huawCRlo9H4) by [+Lars Bak](https://plus.google.com/117369940038227331789) and [+Kasper Lund](https://plus.google.com/100258330325630692559) (Google I/O 2013) gives historic outline for V8 development and describes motivation for creating Dart language.
* Speed is awesome, but low latency is sublime by [+Hannes Payer](https://plus.google.com/114443265544293073897) at JSConf EU 2013 overviews V8 efforts to minimize latency (GC, parallel compilation) [\[video\]](https://www.youtube.com/watch?v=3vPOlGRH6zk)
* New optimizations in V8 by [Ben L. Titzer](http://research.google.com/pubs/BenTitzer.html) at mloc.js 2014 [\[video\]](http://www.ustream.tv/recorded/43772632)


### Other

* Erik Meijer and [+Lars Bak](https://plus.google.com/117369940038227331789) on&nbsp;Channel 9: [Inside V8 - A Javascript Virtual Machine](http://channel9.msdn.com/Shows/Going+Deep/Expert-to-Expert-Erik-Meijer-and-Lars-Bak-Inside-V8-A-Javascript-Virtual-Machine)&nbsp;(2009)

## Fundamentals

### Talks

* [David Mandelin](http://twitter.com/dmandelin)'s (SpiderMonkey TL) talk&nbsp;Know Your Engines (Velocity Conf 2011) [\[slides\]](http://people.mozilla.com/~dmandelin/KnowYourEngines_Velocity2011.pdf) [\[video\]](http://www.youtube.com/watch?v=dtSOKLvdAto).
* I am trying to [explain *inline-caching* used by JavaScript VMs by writing IC *in* JavaScript](http://mrale.ph/blog/2012/06/03/explaining-js-vms-in-js-inline-caches.html), also see my talk "V8 Inside Out" from WebRebels 2012 [\[slides\]](http://s3.mrale.ph/webrebels2012.pdf) [\[video\]](http://vimeo.com/43334972)

### Articles

* [Andy Wingo](http://twitter.com/andywingo) [blogs about his adventures in V8's](http://wingolog.org/tags/v8) and JavaScriptCore's compilation pipelines
* Jay Conrod's [A tour of V8](http://jayconrod.com/tags/v8) series of posts (covers: object representation, GC and compilation pipeline)

## Miscellaneous

* Can V8 do that?! (me, JSConf 2012) [\[slides\]](http://s3.mrale.ph/jsconf2012.pdf) [[vides]](http://blip.tv/jsconf/jsconf2012-vyacheslav-egorov-6141593)
* [Channel 9: Lars Bak and Steve Lucco: Chakra, V8, JavaScript, Open Source](http://channel9.msdn.com/Shows/Going+Deep/Lars-Bak-and-Steve-Lucco-Chakra-V8-JavaScript-Open-Source)
