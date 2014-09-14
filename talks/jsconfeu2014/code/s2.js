// Initial infrastructure for the SendSites specialization.

load("lodash.js");

var global = (function () { return this; })();

function Vector(x, y) {
  this._x = x;
  this._y = y;
}

Vector.prototype.x = function () { return this._x; };
Vector.prototype['x:'] = function (x) {
  this._x = x;
};

Vector.prototype.y = function () { return this._y; };
Vector.prototype['y:'] = function (y) {
  this._y = y;
}

Vector.prototype['add:'] = function (other) {
  ΣSend$00(this, ΣSend$01(ΣSend$02(this), ΣSend$03(other)));
  ΣSend$04(this, ΣSend$05(ΣSend$06(this), ΣSend$07(other)));
};


Vector.prototype['dot:'] = function (other) {
  return ΣSend$08(ΣSend$09(ΣSend$10(this), ΣSend$11(other)),
                  ΣSend$12(ΣSend$13(this), ΣSend$14(other)));
}

Vector.prototype.toString = function () {
  return 'Vector(' + this._x + ', ' + this._y + ')';
};

function lensum(vs, start, end) {
  var v = new Vector(0, 0);
  for (var i = start; ΣSend$15(i, end); i = ΣSend$16(i, 1)) {
    ΣSend$17(v, ΣSend$18(vs, i));
  }
  return ΣSend$19(v, v);
}

// --------------------- Runtime -----------------------------------

Number.prototype['*'] = function (y) {
  'use strict';
  return this * y;
};

Number.prototype['+'] = function (y) {
  'use strict';
  return this + y;
};

Number.prototype['<'] = function (y) {
  'use strict';
  return this < y;
};

Array.prototype['at:'] =  function (idx) {
  return this[idx];
};

// --------------------- SendSite implementation -------------------

function inherit(f, base) {
  f.prototype = Object.create(base.prototype);
  f.prototype.constructor = f;
}

function CompileHandler(desc) {
  function Template() {
    return function Handler($args) {
      /* $uid */
      return $op;
    };
  }

  desc = _.create(desc, { uid: _.uniqueId() });

  var src = _.template(Template.toString(), desc, { interpolate: /\$(\w+)/g });

  return Function('return ' + src)()();
}

function isBinaryOp(msg) {
  switch (msg) {
    case '*':
    case '+':
    case '<':
      return true;
    default:
      return false;
  }
}

function SendSite(id, message) {
  this.name = "ΣSend$" + _.padLeft(id, 2, '0');
  this.message = message;
  this.argc    = isBinaryOp(message) ?
      1 : (message.split(':').length - 1);
}

SendSite.prototype.link = function (f) {
  print("linking " + this.name + " to " + f);
  f.site = this;
  global[this.name] = f;
};

SendSite.prototype.tag = function () {
  return this.constructor.name;
};

SendSite.prototype.bootstrap = function () {
  var args = _.range(this.argc)
              .map(function (n) { return 'a' + n });
  this.link(CompileHandler({
    args: ['self'].concat(args),
    op: 'self["' + this.message + '"](' + args.join(', ') + ')'
  }));
};

(function () {
  ['x:', '+', 'x', 'x',
   'y:', '+', 'y', 'y',
   '+', '*', 'x', 'x', '*', 'y', 'y',
   '<', '+',
   'add:', 'at:',
   'dot:'].forEach(function (key, idx) {
      new SendSite(idx, key).bootstrap();
  });
})();