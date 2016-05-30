var Heap = function () {
  var KEY = 0;

  var heap = [];

  var floating = [];
  // var pinned = [];

  var links = [];
  var refs  = [];

  var svg, force, drag;

  var floatingGroup,
      textGroup,
      linkGroup,
      refGroup;
      // pinnedGroup;

  function transform(d) {
    if (typeof d.x !== 'number' || typeof d.y !== 'number') {
      throw new Error('bad datum: ' + typeof d + "[" + d.constructor.name + "]" + ": " + d);
    }
    return "translate(" + d.x + "," + d.y + ")";
  }

  function transformText(d) {
    var dy = d.y;
    var dx = ((200 - d.x) < 60) ? d.x - 15 : d.x;
    return "translate(" + dx + "," + dy + ")";
  }

  var SLOT_WIDTH = 40;
  var SLOT_HEIGHT = 10;

  function restart() {
    heap.forEach(function (obj) {
      if (obj.$key === void 0) {
        obj.$key = KEY++;
      }

      if (Array.isArray(obj.slots)) {
        obj.$slots = [];
        var dx = obj.orient === 'h' ? SLOT_WIDTH : 0;
        var dy = obj.orient === 'h' ? 0 : SLOT_HEIGHT;
        var x = 0, y = 0, w = 0, h = 0, n = 0;
        for (var i = 0; i < obj.slots.length; i++) {
          if (obj.slots[i] instanceof Heap.Slot) {
            n = obj.slots[i].n;
          } else {
            n = 1;
          }
          w = Math.max(dx * n, SLOT_WIDTH);
          h = Math.max(dy * n, SLOT_HEIGHT)
          obj.$slots.push({
            x: x,
            y: y,
            w: w,
            h: h,
            cx: x + w / 2,
            cy: y + h / 2
          });
          x += dx * n;
          y += dy * n;
        }
        obj.$box = { w: Math.max(x, SLOT_WIDTH), h: Math.max(y, SLOT_HEIGHT) }
      }
    });

    // pinned = heap.filter(function (obj) { return !!obj.pinned; });
    // floating = heap.filter(function (obj) { return !obj.pinned; });
    // pinned = [];
    floating = heap;

    links = [];
    refs = [];
    heap.forEach(function (obj) {
      if (obj.slots !== void 0) {
        obj.slots.forEach(function (slotValue, idx) {
          if (typeof slotValue === 'object' &&
              (heap.indexOf(slotValue.source) >= 0) &&
              (heap.indexOf(slotValue.target) >= 0)) {
            if (slotValue.source.type === 'klass' && slotValue.target.type === 'klass') {
              links.push(slotValue);
            } else {
              refs.push(slotValue);
            }

            if (obj.type === 'object') {
              var c = obj.$slots[idx];
              slotValue.x0 = c.cx;
              slotValue.y0 = c.cy;
            } else {
              slotValue.x0 = slotValue.y0 = 0;
            }
          }
        });
      }
    });

    force
      .nodes(floating)
      .links([].concat(links, refs))
      .start();
    update();
  }

  function buildObject(obj) {
    if (obj.type !== 'object') {
      return;
    }

    var slots = d3.select(this).selectAll('g').data(obj.slots);
    var g = slots.enter().append('g');
    g.append('rect')
      .attr('x', function (d, i) { return obj.$slots[i].x; })
      .attr('y', function (d, i) { return obj.$slots[i].y; })
      .attr('width', function (d, i) { return obj.$slots[i].w })
      .attr('height', function (d, i) { return obj.$slots[i].h })
      .attr('fill', 'white')
      .attr('class', 'object')
      .attr('stroke', 'black')
    g.append('text')
      .attr('x', function (d, i) { return obj.$slots[i].cx; })
      .attr('y', function (d, i) { return obj.$slots[i].cy; })
      .attr('alignment-baseline', 'middle')
      .attr('text-anchor', 'middle')
      .attr('class', 'object-slot-text')
      .attr('fill', 'black');

    slots.each(function (d, i) {
      var rect = d3.select(this).select('rect');

      var bbox = {x: rect.attr('x')|0, y: rect.attr('y')|0, w: rect.attr('width')|0, h: rect.attr('height')|0};
      var bbox_ = obj.$slots[i];

      var newText;
      if (d === void 0) {
        newText = '';
      } else if (typeof d === 'object' && d.source && d.target) {
        newText = '\u25CF';
      } else {
        newText = String(d);
      }

      var elem = d3.select(this).select('text');
      var text = elem.text();
      elem.text(function () { return newText; });

      if (text !== newText) {
        d3.select(this).select('rect')
          .attr('fill', 'white')
          .transition()
          .attr('fill', 'rgb(255, 215, 0)')
          .transition()
          .duration(750)
          .attr('fill', 'white')
      }

      if (bbox.x != bbox_.x || bbox.y != bbox_.y ||
          bbox.h != bbox_.h || bbox.w != bbox_.w) {
        rect.transition()
          .attr('x', bbox_.x)
          .attr('y', bbox_.y)
          .attr('width', bbox_.w)
          .attr('height', bbox_.h)
        elem.transition()
          .attr('x', bbox_.cx)
          .attr('y', bbox_.cy)
      }
    });
    slots.exit().remove();
  }

  var buildHexagonPath =
      d3.svg.line()
            .x(function(d) { return d.x; })
            .y(function(d) { return d.y; })
            .interpolate("cardinal-closed")
            .tension(1);

  function buildHexagon(g, x0, y0, radius) {
    var h = Math.sqrt(3) / 2,
        hexagonPoints = [
          { x: x0 + radius    , y: y0              },
          { x: x0 + radius / 2, y: y0 + radius * h },
          { x: y0 - radius / 2, y: y0 + radius * h },
          { x: x0 - radius    , y: y0              },
          { x: x0 - radius / 2, y: y0 - radius * h },
          { x: x0 + radius / 2, y: y0 - radius * h }
        ];

    var svgContainer =
        d3.select("body")
          .append("svg")
          .attr("width", 500)
          .attr("height", 500);

    return g.append("path")
      .attr("d", buildHexagonPath(hexagonPoints));
  }

  function update() {
    var heapObjects = floatingGroup.selectAll('g.floating').data(floating, function (d) { return d.$key });
    heapObjects.enter()
      .append('g')
      .attr('class', function (d) {
        return 'floating ' + ('t-' + d.type)
      })
      .call(force.drag);
    heapObjects.each(buildObject);
    heapObjects.exit()
      .remove();

    var allLabels = textGroup.selectAll("text").data(heap, function (d) { return d.$key });
    allLabels.enter().append("text")
      .attr("x", 9)
      .attr("y", ".31em")
      .text(function(d) { return d.name || ''; });
    allLabels.exit()
      .remove();

    d3.selectAll(".t-klass")
      .append('circle')
      .attr('r', 6)
      .attr('class', 'klass');

    buildHexagon(d3.selectAll(".t-func"), 0, 0, 8)
      .attr('stroke', '#FF9800')
      .attr('fill', '#FF9800');

    var allLinks = linkGroup.selectAll("path").data(links);
    allLinks.enter().append("path")
      .attr("class", "link-transition")
      .attr("marker-end", function(d) {
        return "url(#arrow-transition-" + d.target.type + ")";
      });
    allLinks.exit()
      .remove();

    var allRefs = refGroup.selectAll("path").data(refs);
    allRefs.enter().append("path")
      .attr("class", "link-ref")
      .attr("marker-end", function (d) { return "url(#arrow-ref-" + d.target.type + ")"; });
    allRefs.exit().remove();
  }

  function createPane() {
    var pane = document.getElementById("right-column");

    if (pane.firstChild != null)
      pane.removeChild(pane.firstChild);

    var width = 200,
        height = 200;

    force = d3.layout.force()
        .nodes(floating)
        .links(links)
        .size([width, height])
        .linkDistance(40)
        .charge(-40)
        .on("tick", tick)
        .start();

    var forceDrag = force.drag().on("dragstart", function (d) {
      d.fixed = true;
    });

    drag = d3.behavior.drag()
        .on("drag", function(d,i) {
            d.x += d3.event.dx
            d.y += d3.event.dy
            d3.select(this).attr("transform", function(d,i){
                return "translate(" + [ d.x,d.y ] + ")"
            })
            tick();
        });

    svg = d3.select("#right-column").append("svg")
        .attr("width", $(pane).width())
        .attr("height", $(pane).height())
        .attr("viewBox", "0 0 " + width + " " + height);

    // Per-type markers, as they don't inherit styles.
    svg.append("defs").selectAll("marker")
        .data([
          { id: 'arrow-transition-klass',
            path: "M5,-5L15,0L5,5"
          },
          { id: 'arrow-ref-klass',
            path: "M5,-5L15,0L5,5"
          },
          { id: 'arrow-transition-func',
            path: "M5,-5L15,0L5,5"
          },
          { id: 'arrow-ref-func',
            path: "M5,-5L15,0L5,5"
          },
          { id: 'arrow-transition-object',
            path: "M3,-5L13,0L3,5"
          },
          { id: 'arrow-ref-object',
            path: "M3,-5L13,0L3,5"
          }])
      .enter()
        .append("marker")
          .attr("id", function(d) { return d.id; })
          .attr("viewBox", "0 -5 15 15")
          .attr("refX", 10)
          .attr("refY", -0.4)
          .attr("markerWidth", 10)
          .attr("markerHeight", 10)
          .attr("orient", "auto")
        .append("path")
          .attr("d", function (d) { return d.path ;} );


    // allObjects.forEach(function (obj) { obj.create(); });

    // pinnedGroup = svg.append("g");
    linkGroup = svg.append("g");
    floatingGroup = svg.append("g");
    refGroup = svg.append("g");
    textGroup = svg.append('g');

    restart();

    function tick() {
      linkGroup.selectAll("path").attr("d", linkArc);
      refGroup.selectAll("path").attr("d", linkArc);
      floatingGroup.selectAll('g.floating').attr("transform", transform);
      textGroup.selectAll("text")
        .attr("text-anchor", function (d) {
          return ((200 - d.x) < 60) ? "end" : "start";
        })
        .attr("transform", transformText);
    }

    function bbox(o) {
      var w = o.$box.w, h = o.$box.h;
      return {
        leftTop: {x: o.x, y: o.y},
        leftBottom: {x: o.x, y: o.y + h},
        rightTop: {x: o.x + w, y: o.y},
        rightBottom: {x: o.x + w, y: o.y + h}
      };
    }

    function addAll(arr, start, end) {
      arr.push(start);
      arr.push({x: (start.x + end.x) / 2, y: (start.y + end.y) / 2});
      arr.push(end);
    }

    function ports(o) {
      var box = bbox(o);
      var result = [];

      addAll(result, box.leftTop, box.rightTop);
      addAll(result, box.rightTop, box.rightBottom);
      addAll(result, box.rightBottom, box.leftBottom);
      addAll(result, box.leftBottom, box.leftTop);

      return result;
    }

    function dist2(p0, p1) {
      var dx = p0.x - p1.x;
      var dy = p0.y - p1.y;
      return dx * dx + dy * dy;
    }

    function linkArc(d) {
      var x0 = d.x0 + d.source.x, y0 = d.y0 + d.source.y;
      var x1, y1;

      if (d.target.type === 'object') {
        var p0 = {x: x0, y: y0};
        var points = ports(d.target);
        var cand = 0, dr = dist2(p0, points[0]);
        for (var i = 1; i < points.length; i++) {
          var dr_ = dist2(p0, points[i]);
          if (dr_ < dr) {
            dr = dr_;
            cand = i;
          }
        }

        x1 = points[cand].x;
        y1 = points[cand].y;
      } else {
        x1 = d.target.x;
        y1 = d.target.y;
      }

      var dx = x1 - x0,
          dy = y1 - y0,
          dr = Math.sqrt(dx * dx + dy * dy);



      var f = d.target.type === 'object' ? (3/dr) : (12/dr);
      dx *= f;
      dy *= f;

      var tx = x1 - dx;
      var ty = y1 - dy;
      // return "M" + x0 + "," + y0 + "A" + dr + "," + dr + " 0 0,1 " + tx + "," + ty;
      return "M" + x0 + "," + y0 + "L" + tx + "," + ty;
    }
  }

  function Slot(val, n) {
    this.val = val;
    this.n = n;
  }

  Slot.prototype.toString = function () { return String(this.val); }

  return {
    initialize: function () {
      createPane();
      window.addEventListener( 'resize', createPane, false );
    },

    add: function (obj) {
      if (heap.indexOf(obj) >= 0) return false;
      heap.push(obj);
      return true;
    },

    remove: function (obj) {
      heap = heap.filter(function (e) { return e !== obj });
    },

    refresh: function () { restart() },

    setHeap: function (newHeap) {
      var oldHeap = heap;
      heap = newHeap;
      return oldHeap;
    },

    Slot: Slot
  }
}();

$(function () {
  Heap.initialize();
})

/*
$(function () {
  Heap.initialize();
  var obj1 = { pinned: true, x: 10, y: 10, type: 'object', slots: ['x'] };
  var obj2 = { pinned: true, x: 50, y: 10, type: 'object', slots: ['x', 'y'], orient: 'h' };
  var klass1 = { type: 'klass', name: 'klass1'}, klass2 = { type: 'klass', name: 'klass2'};
  klass1.slots = [{source: klass1, target: klass2}];

  Heap.add(obj1);
  Heap.add(obj2);
  Heap.add(klass1);

  obj1.slots.push({ source: obj1, target: obj2 });
  obj2.slots.push({ source: obj2, target: klass1 });

  Heap.refresh();

  $('#add').click(function () {
    Heap.add(klass2);
  })
});*/

