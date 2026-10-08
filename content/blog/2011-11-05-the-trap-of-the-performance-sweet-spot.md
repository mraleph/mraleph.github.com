---
layout: blogpost
title: The trap of the performance sweet spot
date: 2011-11-05
summary: |
  When writing performance sensitive JavaScript code you can resort to structuring it
  in a way that makes JS look like C. This way you can hit JS'es performance sweet
  spot, but the code itself will leave bitter aftertaste in your mouth.
---


<p class="warn">If you have arrived here from a blog post discussing asm.js please read <a href="/blog/2013/03/28/why-asmjs-bothers-me.html">my own opinion</a> about asm.js</p>

This post is about JavaScript performance but I would like to start it by telling a story that might seem unrelated to JS. Please bear with me if you don't like C.

# A story of a C programmer writing JavaScript

*Mr. C.* is a C programmer as you can probably guess from his name. Today he was asked by his boss to write a very simple function: *given an array of numbered 2d points calculate vector sum of all even numbered points*... He opens his favorite text editor and quickly types something like:

<sidenote>I'll be intentionally skipping some <code>#include</code> boilerplate</sidenote>

```cpp
typedef struct {
  int32_t n;
  double x;
  double y;
} Point;

Point arrayofpoints_sum(Point* points, size_t n) {
  Point sum = { 0, 0, 0 };

  for (size_t i = 0; i < n; i++) {
    if ((points[i].n & 1) == 0) {
      sum.x += points[i].x;
      sum.y += points[i].y;
    }
  }

  return sum;
}
```

Oh, that was pretty easy... There are still some time left, so mr. C. throws in some array creation and benchmarking code:


```cpp
Point* arrayofpoints_create(size_t n) {
  Point* points = (Point*) malloc(n * sizeof(Point));
  for (size_t i = 0; i < n; i++) {
    points[i].n = i;
    points[i].x = i * 0.1 + 0.1;
    points[i].y = i * 0.9 - 0.1;
  }
  return points;
}

void arrayofpoints_free(Point* array) {
  free(array);
}

static uint64_t now() {
  struct timeval t;
  gettimeofday(&t, NULL);
  return ((uint64_t) t.tv_sec) * 1000000 + (uint64_t) t.tv_usec;
}

void test_arrayofpoints() {
  static const size_t kArraySize = 10000;
  static const size_t kIterations = 10000;

  uint64_t create_total = 0;
  uint64_t sum_total = 0;

  for (size_t i = 0; i < kIterations; i++) {
    uint64_t t1 = now();
    Point* array = arrayofpoints_create(kArraySize);
    uint64_t t2 = now();
    Point sum = arrayofpoints_sum(array, kArraySize);
    uint64_t t3 = now();
    assert((int)sum.x == 2500000);
    assert((int)sum.y == 22495000);
    assert(sum.n == 0);
    arrayofpoints_free(array);

    create_total += (t2 - t1);
    sum_total += (t3 - t2);
  }

  printf("create: %lld [%.2f per iteration] usec, sum: %lld [%.2f per iteration] usec\n",
         create_total, (double)create_total / kIterations,
         sum_total, (double)sum_total / kIterations);
}

int main(int argc, char* argv[]) {
  test_arrayofpoints();
  return 0;
}
```

His code seems to compile and run just fine:

```console
$ gcc --std=c99 -O3 -o point point.c
$ ./point
create: 508075 [50.81 per iteration] usec, sum: 214779 [21.48 per iteration] usec
```

Suddenly mr. C gets a call from his boss. *"We've decided to rewrite our apps in JavaScript. It is pretty fast nowdays, ya know."* says the boss and hangs up. Mr. C. does not like JavaScript as much as he likes C but he is one of those programmers who can write programs in any language:

```js
function Point(n, x, y) {
    this.n = n;
    this.x = x;
    this.y = y;
}

function sumArrayOfPoints(points) {
    var sum = new Point(0, 0, 0);

    for (var i = 0; i < points.length; i++) {
        if ((points[i].n & 1) === 0) {
            sum.x += points[i].x;
            sum.y += points[i].y;
        }
    }

    return sum;
}

function createArrayOfPoints(n) {
    var points = new Array(n);
    for (var i = 0; i < n; i++) {
        points[i] = new Point(/* n */ i, /* x */ i * 0.1 + 0.1, /* y */ i * 0.9 - 0.1);
    }
    return points;
}

function now() {
    return Date.now() * 1000;
}

function assertStrictlyEqual(expected, value) {
  if (expected !== value) {
    throw new Error("Assertion failed: expected " + expected + " got " + value);
  }
}

function testArrayOfPoints() {
    var kArraySize = 10000;
    var kIterations = 10000;

    var createTotal = 0;
    var sumTotal = 0;

    for (var i = 0; i < kIterations; i++) {
        var t1 = now();
        var array = createArrayOfPoints(kArraySize);
        var t2 = now();
        var sum = sumArrayOfPoints(array);
        var t3 = now();
        assertStrictlyEqual(2500000, sum.x | 0);
        assertStrictlyEqual(22495000, sum.y | 0);
        assertStrictlyEqual(0, sum.n);

        createTotal += (t2 - t1);
        sumTotal += (t3 - t2);
    }

    console.log("create: " + createTotal + " [" + (createTotal / kIterations) + " per iteration] usec," +
                " sum: " + sumTotal + " [" + (sumTotal / kIterations) + " per iteration] usec\n");
}

testArrayOfPoints();
```

That was very easy, but the numbers don't look as impressive as mr. C. or his boss expected:

```console
$ ~/src/v8/d8 point1.js
create: 4629000 [462.9 per iteration] usec, sum: 2056000 [205.6 per iteration] usec
```

JavaScript program is approximately 10 times slower than original C program. *Hmm* thinks mr. C. and starts digging.

# If C is a stone then JavaScript is a fog

C is a low-level programming language. People call it a *portable assembly* sometimes. You just take a piece of memory and say: hey, this smallish sequence of 24 bytes is actually a `Point` which has one `uint32_t` field followed by two `double` fields.

<img src="images/2011-11-05/point-structure-c.png" class="centered blend" />

Small chunk of unused memory between `n` and `x` appears to make `x` and `y` fields nicely aligned. CPUs &hearts; aligned doubles. On some architectures you can't even read an unaligned one directly from memory into a floating point register (you'll get punished if you try).

Arrays in C are also nice and tight: you just take a bigger region of memory and assume that it contains a sequence of `Point`s one after another.

<img src="images/2011-11-05/array-of-points-structure-c.png" class="centered blend" />

But in JavaScript things are destined to get hairy. You can't take a flat piece of memory and call it `Point` with this and that as fields. Instead you have an extremely flexible thing called `Object`. `Object` can have *properties* which can come and go as they wish (almost). You can write constructor:


```js
function Point(n, x, y) { /* ... */ }
```

but nothing actually prevents you from modifying `Point` instances after they were created. VM that runs JavaScript has to be always ready for virtually anything that can happen with your object (new properties added, old properties deleted, property *descriptor* modified). Because of this flexibility it can't pack Point objects into 24 bytes and has to go with something like this (example layout used by V8):

<img src="images/2011-11-05/point-structure-javascript.png" class="centered blend"/>

V8 actually tries to make the object more *struct* like. It attempts to figure out how much space should be preallocated directly inside the object for properties by looking at the constructor and/or doing allocation profiling. Some VMs just use a fixed constant or even store all properties outside of an object in a separate array. Another thing to notice is that V8 always boxes numbers that are not 31-bit integers (32-bit on x64). Some VMs (e.g. SpiderMonkey and JSC) don't box doubles but instead use *NaN-tagging* instead.

Nevertheless `Point` object will be 3.3 times as big on x64 version of V8 than it was in `C` program and it will not be continuously allocated in memory (doubles are accessed via indirection). There are three additional fields: pointer to *hidden class* (known as `Map` in V8, `Shape` in SpiderMonkey, `Structure` in JavaScriptCore) which captures and describes layout of the object, pointer to *out of object properties* backing store and pointer to *elements* backing store. All these fields are required because object can be mutated in an unpredictable ways after it's creation.

Array of points object looks basically the same:

<img src="images/2011-11-05/array-of-points-structure-javascript.png" class="centered blend" />

Array is a JavaScript object and thus it also has hidden class, pointer to the properties backing store and pointer to the elements backing store. Backing stores can have different representations. For example VMs usually try to represent sparse arrays as *dictionaries* and non-sparse arrays should have flat backing stores. In our program array of points is always non-sparse and it gets a flat backing store.

The mathematics of performance is simple: each point of flexibility and each indirection (arrow on the picture) adds additional runtime cost. Evaluating simply looking expression `points[i].x` in JavaScript requires answering to an expensive questions: *"What is `points`? How do I get property called `i` from it? How then I get `x`?"*. Fully statical analysis of the program is too expensive to be used to answer these questions. Instead modern JITs reduce these costs by adapting generated code to the program while it runs via techniques like *inline caching* and adaptive compilation pipelines. Simply speaking: because in JavaScript an application can't tell compiler *"`points` is an array of `Point` objects"* via types declarations JIT has to *eavesdrop* to notice that.

If you want to get good performance you need to speak loud enough for JIT compiler to hear you and adapt to your application. This means: your objects should have stable layouts, property access and call sites better be monomorphic, no funny language features (e.g. with or eval) in sight, using typed arrays where appropriate instead of pure JS arrays etc. In a sense you'll be writing statically typed code in a language that does not support static typing.

*"Wait a second!"*  somebody might say here *"Mr. C's code above is pretty damn type stable and yada-yada. But it's still 10x times slower! Can he make it faster?"*

Yes, he can but he will have to

# Write JavaScript as if it's assembly generated by C compiler

To get as close as possible to raw memory from JavaScript we have to use WebGL typed arrays. It's easy for a JIT to befriend those guys and optimize the hell out of reads and writes, because they have a nice semantics for their backing stores: no nasty *holes* leading to prototype lookups, all elements have known *primitive* type and no boxing is required.

```js
var blocks = [];

function Block(size) {
    this.size = size;
    this.buf = new ArrayBuffer(this.size);
    this.i32 = new Int32Array(this.buf);
    this.f64 = new Float64Array(this.buf);
}

function malloc(N) {
    if (blocks[N] && blocks[N].length) return blocks[N].pop();
    return new Block(N);
}

function free(addr) {
    (blocks[addr.size] || (blocks[addr.size] = [])).push(addr);
}
```

This is a very na&iuml;ve implementation (I would even say *parody*) of the famous `malloc`&`free` duo. It does not try to optimize memory usage at all but it is perfect for our demonstration.

```js
var $stack = malloc(8 * 1024);
var $sp = 0;
```

Original C program returns `sum` on the stack so will have our toy stack to mimic that.

```js
function createArrayOfPoints(n) {
    var points = malloc(24 * n);
    var points_i32 = points.i32;
    var points_f64 = points.f64;
    for (var i1 = 0, i2 = 1, i = 0; i < n; i++, i1 += 6, i2 += 3) {
        points_i32[i1]     = /* n */ i;
        points_f64[i2]     = /* x */ i * 0.1 + 0.1;
        points_f64[i2 + 1] = /* y */ i * 0.9 - 0.1;
    }
    return points;
}
```

Creating array of points is simple: you malloc an array and fill it. It might be hard to read this code and see how it relates to the first JavaScript version or even to the original C function but that's because it actually tries to mimic one of the optimizations every good C compiler tries to do: *strength reduction*. Calculating `points[i]` as `(byte*)points + sizeof(Point) * i` might be wasteful because multiplication is expensive compared to addition so good C compiler will try to replace `points[i]` with a new artificial induction variable `p'` that starts as `p' = points[i]` and is advanced as `p += sizeof(Point)`.


```js
function sumArrayOfPoints(points, n) {
    var x = 0;
    var y = 0;

    var points_i32 = points.i32;
    var points_f64 = points.f64;
    for (var i1 = 0, i2 = 1, k = 6 * n; i1 < k; i1 = i1 + 6, i2 = i2 + 3) {
        if ((points_i32[i1] & 1) === 0) {
            x += points_f64[i2];
            y += points_f64[i2 + 1];
        }
    }

    // Caller should have reserved space for the return value.
    var retval_addr = $sp - 24;
    $stack.i32[retval_addr >> 2] = 0;
    $stack.f64[(retval_addr + 8) >> 3] = x;
    $stack.f64[(retval_addr + 16) >> 3] = y;
    return retval_addr;
}
```

Summing loop was translated from C in the same way as initialization loop in `createArrayOfPoints` but there is another important classical optimization demonstrated here: *scalar replacement*. Smart compiler sees (via *escape analysis* usually) that `Point sum` does not have to exist as a continuos entity on the stack. Instead it can be exploded and its fields becomes separate variables (register allocator later puts them into registers). Result of the `sumArrayOfPoints` is returned on the "stack" just like in the original C version.

The rest of code is unchanged but minor changes are required in the `testArrayOfPoints` function:

```js
        var t1 = now();
        var array = createArrayOfPoints(kArraySize);
        var t2 = now();
        $sp += 24;  // Reserve space for return value on the "stack".
        sumArrayOfPoints(array, kArraySize);
        $sp -= 24;
        var sum_n = $stack.i32[$sp >> 2];
        var sum_x = $stack.f64[($sp + 8) >> 3];
        var sum_y = $stack.f64[($sp + 16) >> 3];
        var t3 = now();
        assertStrictlyEqual(2500000, sum_x | 0);
        assertStrictlyEqual(22495000, sum_y | 0);
        assertStrictlyEqual(0, sum_n);
        free(array);
```

We have to take care of managing stack space for stack allocated `sum` object and we should remember to `free` allocated array of points. We are using JavaScript as assembly after all...

<sidenote>If you are curious enough to look at the code V8 generates for the sum loop and compare it with code generated from C by GCC you will notice that while it is pretty tight V8 does not understand that i32 and f64 are actually the same array and treats them separately. There are also bounds checks that are not there for C code.</sidenote>

```console
$ ~/src/v8/d8 point.c.js
create: 532000 [53.2 per iteration] usec, sum: 988000 [98.8 per iteration] usec
```

As you can see in exchange for completely unreadable JavaScript code we got a nice 9x speedup on creation and 2x speedup on sum calculation.

# Don't be charmed by the sweet spot

Roughly a week ago a friend of mine sent me a link to <a href="https://github.com/mbebenita/Broadway">Broadway.js</a> accompanied by numerous expletives to better convey his excitement with this project and <a href="https://github.com/kripken/emscripten">emscripten</a> in general: *"Look how mighty fast JavaScript became, old chap!"*.

My friend has fallen into the logical trap without even noticing it. Good performance demonstrated by some inhumanly written piece of code (e.g. translated from C via optimizing compiler) does not prove that *"JavaScript is already fast enough"* unless you are planning on writing your webapps in C for the rest of your life or you are capable of writing such inhuman code yourself just like mr. C. Instead it proves that *"Certain features of JavaScript when used in certain way lead to good enough performance."* Efficiency on a tight computational kernel does not necessarily translate into efficiency on different workloads. I call this *the trap of the sweet spot*.

It's not JavaScript that becomes faster and faster. It's JavaScript's *sweet spot*.

You can hit the sweet spot, no doubt about that. But you have to follow rules to hit it. And those rules are *strict* (application runs best when it's actually pretty static in it's behavior) and sometimes *unknown* (different VMs rely on different heuristics). And hitting the sweetest part requires some strange engineering decisions as demonstrated by the mr. C.'s example above.

Obviously JavaScript VMs are nowhere near the end of the performance improvements road and the language itself is going to get features like <a href="http://wiki.ecmascript.org/doku.php?id=harmony:binary_data">binary data</a> that would make hitting sweet-sweet spot much easier. But I doubt that the language as whole is going to become performance sweet.

Real world performance is not as shallow as some micro-benchmark score. It has at least three very important facets: speed, memory, VM's complexity.

<sidenote>But I must admit: working on a JavaScript VM and making sweet spot larger and easier to hit is an interesting challenge that make one burst with excitement and stresses the brain. :-)</sidenote>

If you look at existing JavaScript VMs you will notice that they have to pay a lot in terms of complexity to overcome ineffective execution or memory utilization. And implementation complexity is the worst kind of complexity in the world: it leads to subtle bugs that occur on 0.000001% of programs, it leads to unpredictable and hard to analyze performance, it leads to volumes of rulebooks that specify how to appease the compiler.

JavaScript is a complex and expensive language in it's very core. Keep that in mind and don't be charmed by the sweet spot.
