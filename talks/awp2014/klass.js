// Animations for the Hidden Classes slides
var Klass = function () {
  var undo = [];

  function Box(val) {
    this.val = val;

    this.type = 'object';
    this.orient = 'h';
    this.slots = [this.val];
  }

  // Bpox.prototype.toString = function () { return this.val.toFixed(2) }
  //
  var objects = {
    point1: { type: 'object', fixed: true, x: 0, y: 0, slots: [new String(''), new String(''), new String(''), new String(''), new String('')]},
    point2: { type: 'object', fixed: true, x: 50, y: 0, slots: [new String(''), new String(''), new String(''), new String(''), new String('')]},
    array: { type: 'object', fixed: true, x: 0, y: 30, slots: ['', '', '0']},
    smiBacking: { type: 'object', fixed: true, x: 50, y: 40, orient: 'h', slots: [new String('')] },
    proto: {type: 'object', slots: ['', '', '', '']},
    f: {type: 'func', name: 'foo'},
    g: {type: 'func', name: 'bar'},
    vector: { type: 'object', slots: ['', '', '', ''] }
  };

  var klasses = {
    p: { type: 'klass', name: "Point {}" },
    px: { type: 'klass', name: "Point {x}" },
    pxy: { type: 'klass', name: "Point {x, y}"},
    pxyz: { type: 'klass', name: "Point {x, y, z}" },
    arr: { type: 'klass', name: '[]' },
    arrSmi: { type: 'klass', name: "[smi]"},
    arrDbl: { type: 'klass', name: "[double]" },
    proto0: { type: 'klass', name: '{f, g}'},
    proto1: { type: 'klass', name: '{f: foo, g: bar}'},
    vector0: { type: 'klass', name: 'Vec2{x: double, y: double}'}
  };

  function link(src, tgt) {
    if (src.slots === void 0) {
      src.slots = [];
    }

    src.slots.push({source: src, target: tgt});
  }

  link(klasses.p, klasses.px);
  link(klasses.px, klasses.pxy);
  link(klasses.pxy, klasses.pxyz);

  link(klasses.arrSmi, klasses.arrDbl);
  link(klasses.arrDbl, klasses.arr);


  function NewObject(obj) {
    return function () {
      Heap.add(obj);
      undo.push(function () {
        Heap.remove(obj);
      });
    }
  }

  // function SetKlass(object, klass) {
  //  return function() {
  //    var oldLink = object.slots[0];
  //    undo.push(function () {
  //      object.slots[0] = oldLink;
  //    });
  //    object.slots[0] = { source: object, target: klass() };
  //  };
  // }

  function Store(object, field, value) {
    return function () {
      var obj = object;
      obj.slots = obj.slots || [];
      var oldValue = obj.slots[field];
      var oldLength = obj.slots.length;
      undo.push(function () {
        obj.slots[field] = oldValue;
        obj.slots.length = oldLength;
      });
      if (typeof value === 'object' && value.type) {
        if (Heap.add(value)) {
          undo.push(function () { Heap.remove(value); });
        }
        obj.slots[field] = {source: obj, target: value};
      } else {
        obj.slots[field] = value;
      }
    };
  }

  function SetKlass(object, klass) {
    return Store(object, 0, klass);
  }

  function BoxSlot(object, field) {
    return function () {
      var oldValue = object.slots[field];
      var box = new Box(oldValue);
      if (object.$slots) {
        box.x = object.x + object.$slots[field].x;
        box.y = object.y + object.$slots[field].y;
      }
      NewObject(box)();
      Store(object, field, box)();
    };
  }

  function StartStage() {
    currentStage++;
    undo.push(function () { currentStage--; });
  }

  function Clear() {
    var h = Heap.setHeap([]);
    undo.push(function () { Heap.setHeap(h); })
  }

  function HeapRemove(val) {
    return function () {
      Heap.remove(val);
      undo.push(function () { Heap.add(val); });
    }
  }

  var sqrt2 = new Box(new Heap.Slot(Math.sqrt(2).toFixed(2), 2));
  var strXyz = new Box("xyz");

  var box1 = new Box(new Heap.Slot('0.1', 2));
  var box2 = new Box(new Heap.Slot('0.2', 2));

  var stages = [
    [],
    [],
    [NewObject(objects.point1), SetKlass(objects.point1, klasses.p)],
    [SetKlass(objects.point1, klasses.px), Store(objects.point1, 1, '1')],
    [SetKlass(objects.point1, klasses.pxy), Store(objects.point1, 2, '2')],
    [],
    [NewObject(objects.point2), SetKlass(objects.point2, klasses.p)],
    [SetKlass(objects.point2, klasses.px), Store(objects.point2, 1, '3')],
    [SetKlass(objects.point2, klasses.pxy), Store(objects.point2, 2, '4')],
    [SetKlass(objects.point2, klasses.pxyz), Store(objects.point2, 3, '5')],
    [Clear],
    [NewObject(objects.array), SetKlass(objects.array, klasses.arr), NewObject(objects.smiBacking), Store(objects.array, 1, objects.smiBacking)],
    [Store(objects.smiBacking, 1, 0), Store(objects.array, 2, 1)],
    [Store(objects.smiBacking, 2, 1), Store(objects.array, 2, 2)],
    [Store(objects.smiBacking, 3, sqrt2), Store(objects.array, 2, 3)],
    [HeapRemove(sqrt2), SetKlass(objects.array, klasses.arrSmi), Store(objects.smiBacking, 3, '')],
    [SetKlass(objects.array, klasses.arrDbl)],
    [Store(objects.smiBacking, 1, new Heap.Slot('0.0', 2)),
     Store(objects.smiBacking, 2, new Heap.Slot('1.0', 2)),
     Store(objects.smiBacking, 3, new Heap.Slot('', 2))],
    [
     Store(objects.smiBacking, 3, new Heap.Slot(Math.sqrt(2).toFixed(2), 2))
    ],
    [
      NewObject(strXyz)
    ],
    [
      SetKlass(objects.array, klasses.arr),
      BoxSlot(objects.smiBacking, 1),
      BoxSlot(objects.smiBacking, 2),
      BoxSlot(objects.smiBacking, 3),
    ],
    [
      Store(objects.smiBacking, 4, strXyz),
    ],
    [Clear],
    [
      NewObject(objects.vector)
    , SetKlass(objects.vector, klasses.vector0)
    , Store(objects.vector, 1, box1)
    , Store(objects.vector, 2, box2)
    ],
    [
    , Store(box1, 0, new Heap.Slot('1.1', 2))
    , Store(box2, 0, new Heap.Slot('1.2', 2))
    ],
    [NewObject(new Box(new Heap.Slot('1.1', 2)))],
    [NewObject(new Box(new Heap.Slot('1.1', 2)))],
    [NewObject(new Box(new Heap.Slot('1.1', 2)))],
    [Clear],
    [NewObject(objects.proto)
    , SetKlass(objects.proto, klasses.proto0)
    , Store(objects.proto, 1, objects.f)
    , Store(objects.proto, 2, objects.g)
    ],
    [ HeapRemove(klasses.proto0)
    , SetKlass(objects.proto, klasses.proto1)
    , Store(klasses.proto1, 0, objects.f)
    , Store(klasses.proto1, 1, objects.g)
    , Store(objects.proto, 1, '')
    , Store(objects.proto, 2, '')
    ]

  ];

  var currentStage = 0;
  function toStage(stage) {
    if (currentStage == stage) {
      return;
    }

    while (currentStage > stage) {
      undo.pop() ();
    }

    while (currentStage < stage) {
      StartStage();
      stages[currentStage].forEach(function (cmd) {
        cmd();
      });
    }

    Heap.refresh();
  }

  return {
    toStage: toStage
  }
}();
