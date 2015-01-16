---
layout: blogpost
title: new Fn(...) vs. Object.create(P)
date: 2014-07-30
---

_This is a note in reply to Kyle Simpson's [question](https://twitter.com/getify/status/494301107049349120)_ 

## Basics of object layout in V8

Each JavaScript object in V8 looks like this

<pre class="shaky">
+-------+
|   *---+-> hidden class (aka map)
+-------+
|   *---+-> out-of-object properties storage
+-------+
|   *---+-> elements storage
+-------+
|   1   +-+
+-------+ |
|   2   | |
+-------+  > N slots reserved for in-object properties
~~~~~~~~~ |
+-------+ |
|   N   +-+
+-------+
</pre>

There are several important things to note here: 

* Objects can have `0` in-object property slots use a dictionary for out-of-object property storage. This is a very generic and slow representation of a JavaScript object (aka *dictionary mode*). *Fast mode* JavaScript objects have `0` or more in-object properties slots and use an array for out-of-object property storage;
* The more properties are stored in-object the better: it requires one less indirection to access them and also does not waste any memory on array header for out-of-object storage;
* Once the object is allocated it is **impossible** to increase the amount of in-object slots for properties. If program continues to add properties to an object that has not free in-object slots then all newly added properties are going into the out-of-object storage which can be grown dynamically --- of course growing it dynamically also costs. That's why it is extremely important to have a good approximation of how properties an object is going to have in total; 
* Hidden class (aka *map*) completely describes layout of the object: how big this object is, which properties does it have and where (for fast mode objects), how many in-object property slots are already used etc. Hidden classes themselves are essentially immutable and everytime a new property is added to the object, this object has to switch to a new hidden class;

### Example 

Lets imagine what happens if V8 decides to give an object literal `1` in-object slot and we then add three properties to this object. 

{% highlight javascript %}
var obj = {};
obj.x = 0;
obj.y = 1;
obj.z = 2;
{% endhighlight %}

The evolution of the object in the heap will go as follows:

<ol>
<li>
<p>Initially it will be empty and have an "empty" hidden class</p>
<pre class="shaky">    
+-------+
|   *---+-> #0 { /* empty hidden class */ }
+-------+
|   *---+-> [ /* empty array */ ]
+-------+
|   *---+-> [ /* empty array */ ]
+-------+
|       | <- one slot reserved for in-object properties
+-------+  
</pre>
</li>
<li><p>Once we add <code>x</code> the hidden class will change to a new one, which says that object contains property called in the first in-object slot and the value will be stored inside the slot</p>
<pre class="shaky">    
+-------+
|   *---+-> #1 { x: @in 0 }
+-------+
|   *---+-> [ /* empty array */ ]
+-------+
|   *---+-> [ /* empty array */ ]
+-------+
|   0   |
+-------+  
</pre>
</li>
<li>
<p>When we try to add <code>y</code> there will be no space inside the object left, so V8 will allocate an array for out-of-object properties and store <code>y</code>'s value there. Hidden class will be changed once again to reflect this</p>
<pre class="shaky">
+-------+
|   *---+-> #2 { x: @in 0, y: @out 0 }
+-------+
|   *---+-> [ 1 , _, _ ]
+-------+
|   *---+-> [ /* empty array */ ]
+-------+
|   0   |
+-------+  
</pre>
<p>Notice that V8 overallocated the out-of-object storage a bit, anticipating addition of more properties (growing the storage one property at a time would lead to quadratic complexity and produce garbage).</p>
</li>
<li>
<p>When we try to add <code>z</code> there will be still no space inside the object, but enough space in the out-of-object storage so V8 will just use that.</p>
<pre class="shaky">
+-------+
|   *---+-> #3 { x: @in 0, y: @out 0, z: @out 1 }
+-------+
|   *---+-> [ 1 , 2, _ ]
+-------+
|   *---+-> [ /* empty array */ ]
+-------+
|   0   |
+-------+  
</pre>
<p>This example once again illustrates why it is very important to estimate the amount of in-object slots ahead of object allocation to achieve the most effecient representation after all properties are added.</p>
<p><em>Sidenote: if we execute the same code again, <b>no</b> new hidden classes will be allocate and we will arrive to the same hidden class in the end. This is a very important invariant and a lot of optimizations that happen in V8 are centered around it.</em></p>
</li>
</ol>

## Estimating expected amount of properties.

When we allocate the very first object through a constructor `new Fn(...)` V8 has to create an _initial hidden class_ for this constructor: this will be the hidden class of an object at the very beginning of the constructor body, before execution of any statements within the constructor happens. When V8 allocates initial hidden class it has to decide how many slots for in-object properties to reserve inside the object and as noted above it will not be able to give more to the object once it is allocated (more about it later).

What V8 does here is: it looks through the body of `Fn` for assignments of form `this.x`, counts them and uses this number plus some slack on top as an expected number of properties for this object.

Optimistically adding the slack without wasting memory is possible because V8 also does a bit of runtime profiling, so called _in-object slack tracking_ - runtime looks at the maximum amount of in-object slots that were used after certain amount of allocations happened and then reduces amount of reserved slots to match it. Due to a careful selection of the filler value runtime puts into unused slots at allocation, V8 is able to shrink all allocated instances belonging to the same transition tree just by rewriting instance sizes stored in individual hidden classes and objects themselves don't need to be fixed in any way.

## `new Fn(...)` vs. `Object.create(P)`

Now we are ready to dive into why constructor can be more efficient than `Object.create` based idioms.

If we profile `new Fn(...)`-case from Kyle's benchmark then we'll see that most of the time is spent in the generated code. Data from the `Object.create(P)`-case however reveals two hotspots in the V8's runtime system that together are responsible for 80% of the whole execution time `SharedStoreIC_ExtendStorage` (50%) and `Runtime_SetPrototype` (30%).

### `SharedStoreIC_ExtendStorage`

As explained above V8's heuristic that is responsible for approximating amount of pre-reserved in-object property slots are centered around constructors and do not cover `Object.create(P)` which is essentially implemented like this:

{% highlight javascript %}
Object.create = function (P) {
  return { __proto__: P };
};
{% endhighlight %}

Resulting object gets the same amount of in-object slots any other object allocated through the empty object literal would get `0` - which is obviously not enough for this case and it even forces V8 to grow out-of-object storage several times as new properties are added.

### `Runtime_SetPrototype`

Setting prototype of an object in V8 currently requires falling into runtime system where we will have to find a new appropriate hidden class for an object and transition an object to it.

## Q&amp;A

### Is there anything V8 could do to improve `Object.create(P)` performance?

Certainly yes. There are two things that could be improved:

1. Normal property stores don't have to go through the runtime all the time (even if they cause hidden class switch). In a similar manner `__proto__`-store can be improved to avoid always going into runtime;
2. `Object.create` could be treated in a similar way to constructor. We just have to realize that the hidden class of `{ __proto__: P }` for a fixed `P` is essentially just like an initial map for a constructor. This means we could first over-allocate in-object property slots and then rely on slack-tracking to shrink the objects for us (though of course it would require to generalize slack-tracking machinery a bit).

### Why not switch to a "larger" hidden class after several allocations?

Polymorphism is the main reason why V8 choose to shrink objects instead of starting to allocate bigger ones once it discovers that it did not give enough in-object slots from the start.

As noted above it is impossible to grow objects once they are allocated, which means VM can't simply rewrite transition tree and increase instance size stored inside each hidden class by some amount.

Instead the only possibility is to duplicate the transition tree, increase sizes stored in it, and switch constructor's initial map to point to a new one.

However at this point constructor will start producing objects with a new hidden class and this will turn polymorphic all sites that see both previously constructed objects and newly constructed ones.

There are certain way to avoid this polymorphism, but none of them are simple or without drawbacks. For example you could introduce a notion of a _deprecated_ hidden class which does not get recorded in the ICs and which gets replaced by a non-deprecated counterpart at GC time (as GC is the only time runtime could migrate and grow the object).

<script type="text/javascript" src="/js/shaky.dart.js">
</script>