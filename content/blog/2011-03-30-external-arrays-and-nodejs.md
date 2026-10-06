---
layout: blogpost
title: Improved V8 external arrays support and nodejs Buffer type
date: 2011-03-30
summary: |
  Crankshaft can finally optimize elementwise access to external arrays. This offers significant performance boost to
  node.js.
---

Recently V8's optimizing pipeline (Crankshaft) got full support for external arrays (aka WebGL typed arrays).
One of core NodeJS types - `Buffer` - is exposed to JavaScript code as _an external unsigned byte array_. So I decided
to do a small unscientific benchmark to see the improvement with my own eyes:

```js
var LONG_STRING = "qwertyuiop";

for (var i = 0; i < 13; i++) LONG_STRING += LONG_STRING;

// force cons-string flattening outside of timed loop.
LONG_STRING.charCodeAt();

console.log("LONG_STRING is %s chars long", LONG_STRING.length);

function Str2BufferJS(s) {
  var length = s.length;
  var b = new Buffer(length);
  for (var i = 0; i < length; i++) b[i] = s.charCodeAt(i);
  return b;
}

function Str2BufferNative(s) {
  var length = s.length;
  var b = new Buffer(length);
  b.asciiWrite(s, 0);
  return b;
}

var N = 1000;

function LoopAndTime(name, f) {
 var start = Date.now();
 for (var i = 0; i < N; i++) f();
 var end = Date.now();
 console.log("%s took %s ms per %s calls", name, end - start, N);
}

LoopAndTime("Str2BufferNative", function() { Str2BufferNative(LONG_STRING); });
LoopAndTime("Str2BufferJS", function() { Str2BufferJS(LONG_STRING); });
```

Results were fascinating:

```
# node 0.4.4 with V8 3.1.8.5
LONG_STRING is 81920 chars long
Str2BufferNative took 224 ms per 1000 calls
Str2BufferJS took 1180 ms per 1000 calls
# node 0.4.4. with V8 3.2.7 (current bleeding_edge)
LONG_STRING is 81920 chars long
Str2BufferNative took 254 ms per 1000 calls
Str2BufferJS took 231 ms per 1000 calls
```

As you can see JS function optimized by Crankshaft is now on par with native implementation of `Buffer.asciiWrite`.