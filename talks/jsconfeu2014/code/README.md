# "Smalltalk"-ified benchmarks

Note this is not a fully functional implementation of a smalltalk runtime. It's an illustration of how certain techniques can be useful when implementing aforementioned runtime on top of JavaScript VM.

This folder contains versions of the code used to reproduce the numbers on the slides (at least those that do not requires VM changes). V8 patches that tweak various heuristics inside the VM are *not* included because they are way too hacky and I don't want to encourage random tweaks like that. See below for outline of the changes needed in the VM.

You can benchmark individual steps with 

    $ d8 sX.js measure.js

You can check semantics implemented in a particular step with

    $ d8 sX.js semantics.js
    
### V8 changes required for peak performance

When preparing for the talk I did the following tweaks to the V8 optimization pipeline:

* change inlining heuristics to force inline global function invocation if the name of the variable starts with `Σ`;
* constant fold context slot loads if context itself is a constant and loaded slot is assigned only once;
* tweaks in different passes to ignore blocks marked as unreachable. 

