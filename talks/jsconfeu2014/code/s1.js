// First Smalltalkified version that just uses message sends for all basic operations.

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
  Send(this, 'x:', Send(Send(this, 'x'), '+', Send(other, 'x')));
  Send(this, 'y:', Send(Send(this, 'y'), '+', Send(other, 'y')));
};

Vector.prototype['dot:'] = function (other) {
  return Send(Send(Send(this, 'x'), '*', Send(other, 'x')),
              '+',
              Send(Send(this, 'y'), '*', Send(other, 'y')));
}

function lensum(vs, start, end) {
  var v = new Vector(0, 0);
  for (var i = start; Send(i, '<', end); i = Send(i, '+', 1)) {
    Send(v, 'add:', Send(vs, 'at:', i));
  }
  return Send(v, 'dot:', v);
}

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
 
function Send(self, message /*, ... */) {
  if (typeof self[message] === 'undefined') {
    throw new Error('object ' + self + ' does not understand ' + message);
  }
  return self[message].apply(self, Array.prototype.slice.call(arguments, 2));
}