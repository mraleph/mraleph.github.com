# "Smalltalk"-ified benchmarks

Note this is not a fully functional implementation of a smalltalk runtime. It's an illustration of how certain techniques can be useful when implementing aforementioned runtime on top of JavaScript VM.

This folder contains versions of the code used to reproduce the numbers on the slides (at least those that do not requires VM changes). V8 patches that tweak various heuristics inside the VM are *not* included because they are way too hacky and I don't want to encourage random tweaks like that.

You can benchmark individual steps with 

    $ d8 sX.js measure.js

You can check semantics implemented in a particular step with

    $ d8 sX.js semantics.js


