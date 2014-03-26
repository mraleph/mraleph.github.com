// Animations for the Hidden Classes slides
$(function () {

  var allNodes = [
    {name: "Point {}", targets: [1] },
    {name: "Point {x}", targets: [2] },
    {name: "Point {x, y}", targets: [3] },
    {name: "Point {x, y, z}" }
  ];

  var allLinks = [];

  allNodes.forEach(function (node) {
    (node.targets || []).forEach(function (target) {
      allLinks.push({
        source: node,
        target: allNodes[target]
      });
    });
  });

  var nodes = [];
  var links = [];
  var refs  = [];

  function refillLinks() {
    links = allLinks.filter(function (link) {
      return nodes.indexOf(link.source) != -1 &&
          nodes.indexOf(link.target) != -1;
    })
  }

  var svg, force;

  var circleGroup, textGroup, linkGroup, refGroup, objGroup;

  var undo = [];

  var curKlass = 0;

  function Obj(x, y, labels) {
    this.x = x;
    this.y = y;
    this.labels = labels;
    this.visible = false;

    this._fields = 0;

    this.svg = null;
    this.ref = { source: { x: this.x + Obj.W / 2, y: this.y + Obj.H / 2 }, target: null };
  }

  Obj.W = 40;
  Obj.H = 10;

  Obj.prototype = {
    create: function () {
      var g = svg.append("g");

      var texts = [];
      for (var i = 0; i < this.labels.length; i++) {
        var val = this.labels[i];
        g.append("rect")
          .attr("x", this.x)
          .attr("y", this.y + Obj.H * i)
          .attr("width", Obj.W)
          .attr("height", Obj.H)
          .attr("class", "object-slot");

        if (typeof val !== "undefined") {
          texts.push(
            g.append("text")
             .attr("x", this.x + Obj.W/2)
             .attr("y", this.y + Obj.H * i + Obj.H/2)
             .attr("alignment-baseline", "middle")
             .attr("text-anchor", "middle")
             .attr("class", "object-slot-text")
             .text(String(val)));
        }
      }

      g.append("circle")
        .attr("cx", this.x + Obj.W/2)
        .attr("cy", this.y + Obj.H/2)
        .attr("r", "2");

      this.svg = { g: g, labels: texts };

      if (!this.visible) {
        this.hide();
      }
    },

    show: function () {
      this.svg.g.attr("class", "");
      this.fields = this.fields;
      this.visible = true;
    },

    hide: function () {
      this.svg.g.attr("class", "invisible");
      this.visible = false;
    },

    get klass () { return this.ref.target; },
    set klass (k) {
      console.log(k);

      if (!k) {
        this.ref.target = null;
        refs.pop();
        return;
      }

      if (this.ref.target == null)
        refs.push(this.ref);

      this.ref.target = k;

      console.log(this.ref.target);
    },

    get fields () {
      return this._fields;
    },

    set fields (n) {
      this._fields = n;
      this.svg.labels.forEach(function (label, idx) {
        label.classed("invisible", idx >= n);
      });
    }
  }

  var objects = [];
  var allObjects = [
    new Obj(0, 0, [undefined, 1, 2, undefined, undefined]),
    new Obj(50, 0, [undefined, 3, 4, 5, undefined])
  ];

  function NewObject() {
    var object = allObjects[objects.length];
    objects.push(object);
    object.show();
    curObj = object;

    undo.push(function () {
      objects.pop().hide();
      curObj = objects[objects.length - 1];
    });
  }

  function NewKlass() {
    curKlass = nodes.length;
    nodes.push(allNodes[nodes.length]);
    undo.push(function () {
      nodes.pop();
    });
  }

  function NextKlass() {
    undo.push(function () { --curKlass; });
    ++curKlass;
  }

  function SetKlass() {
    var oldKlass = curObj.klass;
    undo.push(function () { curObj.klass = oldKlass; });
    curObj.klass = nodes[curKlass];
  }

  function Store() {
    undo.push(function () { curObj.fields--; });
    curObj.fields++;
  }

  function ResetKlass() {
    var _curKlass = curKlass;
    undo.push(function () { curKlass = _curKlass; });
    curKlass = 0;
  }

  function StartStage() {
    currentStage++;
    undo.push(function () { currentStage--; });
  }

  var stages = [
    [],
    [],
    [NewObject, NewKlass, SetKlass],
    [NewKlass, SetKlass, Store],
    [NewKlass, SetKlass, Store],
    [],
    [NewObject, ResetKlass, SetKlass],
    [NextKlass, SetKlass, Store],
    [NextKlass, SetKlass, Store],
    [NewKlass, SetKlass, Store]
  ];

  var currentStage = 0;
  function toStage(slide) {
    var stage = slide.getAttribute("data-stage") | 0;

    if (currentStage == stage) {
      return;
    }

    while (currentStage > stage) {
      undo.pop() ();
    }

    while (currentStage < stage) {
      StartStage();
      stages[currentStage].forEach(function (cmd) { cmd(); });
    }

    refillLinks();

    force.start();

    bindData();
  }

  Reveal.addEventListener('ready', function(event) {
    toStage(event.currentSlide);
  });

  Reveal.addEventListener('slidechanged', function(event) {
    toStage(event.currentSlide);
  });

  function bindData() {
    var allCircles = circleGroup.selectAll("circle").data(nodes);
    allCircles.enter()
      .append("circle")
      .attr("r", 6)
      .attr("class", "klass")
      .call(force.drag);
    allCircles.exit()
      .remove();

    var allLabels = textGroup.selectAll("text").data(nodes);
    allLabels.enter().append("text")
      .attr("x", 9)
      .attr("y", ".31em")
      .attr("text-anchor", function (d) {
        return ((200 - d.x) < 30) ? "end" : "start";
      })
      .text(function(d) { return d.name; });
    allLabels.exit()
      .remove();

    var allLinks = linkGroup.selectAll("path").data(links);
    allLinks.enter().append("path")
      .attr("class", "link-transition")
      .attr("marker-end", function(d) { return "url(#arrow-transition)"; });
    allLinks.exit()
      .remove();

    var allRefs = refGroup.selectAll("path").data(refs);
    allRefs.enter().append("path")
      .attr("class", "link-ref")
      .attr("marker-end", function (d) { return "url(#arrow-ref)"; });
    allRefs.exit().remove();
  }

  function createPane() {
    var pane = document.getElementById("right-column");

    if (pane.firstChild != null)
      pane.removeChild(pane.firstChild);

    var width = 200,
        height = 200;

    force = d3.layout.force()
        .nodes(nodes)
        .links(links)
        .size([width, height])
        .linkDistance(50)
        .charge(-500)
        .on("tick", tick)
        .start();

    svg = d3.select("#right-column").append("svg")
        .attr("width", $(pane).width())
        .attr("height", $(pane).height())
        .attr("viewBox", "0 0 " + width + " " + height);

    // Per-type markers, as they don't inherit styles.
    svg.append("defs").selectAll("marker")
        .data(['arrow-transition', 'arrow-ref'])
      .enter().append("marker")
        .attr("id", function(d) { return d; })
        .attr("viewBox", "0 -5 10 10")
        .attr("refX", 18)
        .attr("refY", -0.4)
        .attr("markerWidth", 6)
        .attr("markerHeight", 6)
        .attr("orient", "auto")
      .append("path")
        .attr("d", "M0,-5L10,0L0,5");


    allObjects.forEach(function (obj) { obj.create(); });

    linkGroup = svg.append("g");
    refGroup = svg.append("g");
    circleGroup = svg.append("g");
    textGroup = svg.append("g");

    bindData();

    // Use elliptical arc path segments to doubly-encode directionality.
    function tick() {
      linkGroup.selectAll("path").attr("d", linkArc);
      refGroup.selectAll("path").attr("d", linkArc);
      circleGroup.selectAll("circle").attr("transform", transform);
      textGroup.selectAll("text").attr("text-anchor", function (d) {
        return ((200 - d.x) < 60) ? "end" : "start";
      });
      textGroup.selectAll("text").attr("transform", transformT);
    }

    function linkArc(d) {
      var dx = d.target.x - d.source.x,
          dy = d.target.y - d.source.y,
          dr = Math.sqrt(dx * dx + dy * dy);
      return "M" + d.source.x + "," + d.source.y + "A" + dr + "," + dr + " 0 0,1 " + d.target.x + "," + d.target.y;
    }

    function transform(d) {
      return "translate(" + d.x + "," + d.y + ")";
    }

    function transformT(d) {
      var dy = d.y;
      var dx = ((200 - d.x) < 60) ? d.x - 15 : d.x;
      return "translate(" + dx + "," + dy + ")";
    }

  }

  createPane();

  window.addEventListener( 'resize', createPane, false );

});
