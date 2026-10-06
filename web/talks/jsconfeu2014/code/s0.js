// Baseline version of the code.

function Vector(x, y) {
  this.x = x;
  this.y = y;
}

Vector.prototype.add = function (other) {
  this.x += other.x;
  this.y += other.y;
};

Vector.prototype.dot = function (other) {
  return this.x * other.x + this.y * other.y;
}

function lensum(vs, start, end) {
  var v = new Vector(0, 0);
  for (var i = start; i < end; i++) {
    v.add(vs[i])
  }
  return v.dot(v);
}