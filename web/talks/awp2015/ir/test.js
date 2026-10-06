function Vec2(x, y) {
  this.x = x;
  this.y = y;
}

Vec2.prototype = {
  len2: function () {
    return this.x * this.x + this.y * this.y;
  },

  len: function () {
    return Math.sqrt(this.len2());
  }
}

function lenOf(v) {
  // We are going to deoptimize here when we call
  // loop the second time because hidden class of
  // v2 does not match hidden class of v.
  // We changed by adding a new property "name" to
  // the object allocated with Vec2.
  return v.len();
}

function loop(v) {
  var sum = 0;
  for (var i = 0; i < 1e5; i++) sum += lenOf(v);
  return sum;
}

var v = new Vec2(0.1, 0.2);
loop(v);

var v2 = new Vec2(0.1, 0.2);
v2.name = "whatever";
loop(v2);