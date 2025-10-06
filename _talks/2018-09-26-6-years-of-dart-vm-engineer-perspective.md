---
layout: talks
conference: Strange Loop
date: 2018-09-26
title: 6 Years Of Dart (VM engineer perspective)
slides: https://drive.google.com/open?id=1sswfb-Ly48IVr76EshnXTsWcA4K5fH4P
video: https://www.youtube.com/watch?v=WjdrUphF5l4
description: |
    Dart might be the only contemporary programming language that changed its core principles so radically between two major versions. 10 years ago, in 2010, it was born as a dynamically typed programming language with optional static types - ideas of Strongtalk wrapped into familiar C-like syntax. A language destined to be executed in a native VM with an adaptive JIT compiler. Yet over the years Dart has evolved into a language with a sound static type system, and is being deployed in contexts that require ahead-of-time compilation and prohibit JITing. Now, it is even trying to get rid of the “billion-dollar mistake” - null - and incrementally transition to non-nullable by default reference types.
    This talk focuses on the architecture of Dart Virtual Machine and how it followed the evolution of the Dart language, adapting to the new semantics and new execution environments, where users wanted to bring Dart to.
---
