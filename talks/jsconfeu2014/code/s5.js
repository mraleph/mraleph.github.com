// SendSite specialization for 'at:' message with bounds checking.

load("lodash.js");

var global = (function () { return this; })();

function Vector(x, y) {
  this._x = x;
  this._y = y;
}

Vector.understands = new Set(['x', 'x:', 'y', 'y:', 'add:', 'dot:']);

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

// --------------------- Template compilation -------------------

function inherit(f, base) {
  f.prototype = Object.create(base.prototype);
  f.prototype.constructor = f;
}

function CompileHandler(desc) {
  function Template() {
    return function Handler($args) {
      /* $uid */
      if ($check) {
        return $op;
      }
      return Handler.site.miss($args);
    };
  }

  desc = _.create({ uid: _.uniqueId(), check: 'true' }, desc);

  var src = _.template(Template.toString(), desc, { interpolate: /\$(\w+)/g });

  return Function('return ' + src)()();
}

// --------------------- SendSite implementation -------------------

function inherit(f, base) {
  f.prototype = Object.create(base.prototype);
  f.prototype.constructor = f;
}

function CompileHandler(desc, env) {
  function Template($_env_args) {
    $_env_vars
    return function Handler($args) {
      /* $uid */
      if ($check) {
        return $op;
      }
      return Handler.site.miss($args);
    };
  }

  env = env || {};
  desc = _.create({
    uid: _.uniqueId(),
    check: 'true',
    _env_vars: _.keys(env).map(function (n) { return "var " + n + " = _" + n + ";"; }).join('\n'),
    _env_args: _.keys(env).map(function (n) { return "_" + n; }).join(',')
  }, desc);

  var src = _.template(Template.toString(), desc, { interpolate: /\$([\w_]+)/g });

  return Function('return ' + src)().apply(null, _.values(env));
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

SendSite.prototype = {
  get handler () {
    return global[this.name];
  }
}

SendSite.prototype.link = function (f) {
  // print("linking " + this.name + " to " + f);
  f.site = this;
  global[this.name] = f;
};

SendSite.prototype.tag = function () {
  return this.constructor.name;
};

SendSite.prototype.bootstrap = function () {
  if (isBinaryOp(this.message)) {
    this.link(CompileHandler({
      args: ['lhs', 'rhs'],
      op: 'lhs ' + this.message + ' rhs',
      check: 'typeof lhs === "number" && ' +
             'typeof rhs === "number"'
    }));
    return;
  }

  var args = _.range(this.argc)
              .map(function (n) { return 'a' + n });
  this.link(CompileHandler({
    args: ['self'].concat(args),
    op: 'null',
    check: 'false'
  }));
};

SendSite.prototype.handleArrayAt = function (self, idx) {
  var ctor = self.constructor;
  if (ctor === Array && (typeof idx !== "number" || (idx < 0) || (idx > self.length))) {
    throw new Error("index " + idx + " out of bounds [0, " + self.length + ")");
  } else if (ctor === Array) {
    this.link(
      CompileHandler({
        args: ['self', 'idx'],
        op: 'self[idx]',
        check: ['typeof idx === "number"',
                'idx >= 0',
                'idx < self.length',
                'self.constructor === ctor'].join('&&')
      }, { ctor: ctor })
    )
    return true;
  }
  return false;
}

SendSite.prototype.miss = function (self) {
  var ctor = self.constructor;
  if (typeof ctor === "function" &&
      ctor.understands instanceof Set &&
      ctor.understands.has(this.message)) {
    var args = _.range(this.argc)
                .map(function (n) { return 'a' + n });
    this.link(
      CompileHandler({
        args: ['self'].concat(args),
        op: 'self["' + this.message + '"](' + args.join(', ') + ')',
        check: 'self.constructor === ctor'
      }, { ctor: ctor })
    )
    return this.handler.apply(null, arguments);
  } else if (ctor === Array &&
             this.message === 'at:' &&
             this.handleArrayAt(self, arguments[1])) {
    return this.handler.apply(null, arguments);
  }
  throw new Error("object " + self + " does not understand " + this.message);
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