import globals
import buffers
import atomics
import bitops
import gamestate
import math

type
  Color = tuple[a, r, g, b: uint8]
  Vec2[T] = tuple[x, y: T]
  TexPoint2d = Vec2[float]
  PixelPoint2d = Vec2[int]
  Rectangle = tuple[x, y, w, h: int]
  AffineMatrix2d = array[6, float]
  Transform = proc (p: TexPoint2d, arg: auto): TexPoint2d
  Renderer*[T] = proc (o: T, p: TexPoint2d): Color

const UNIT: Rectangle = (x: 0, y: 0, w: 1, h: 1)

func toARGB(self: Color): uint32 =
  return rotateLeftBits(uint32(self.a), 24).
    bitor(rotateLeftBits(uint32(self.r), 16)).
    bitor(rotateLeftBits(uint32(self.g), 8)).
    bitor(uint32(self.b))

proc toTexPoint2d(p: PixelPoint2d, bounds: Rectangle): TexPoint2d =
  return (x: float(p.x - bounds.x) / float(bounds.w), y: float(p.y - bounds.y) / float(bounds.h))

func cross(v, w: Vec2[float]): float =
  v.x * w.y - v.y * w.x

func dot(v, w: Vec2[float]): float =
  v.x * w.x + v.y * w.y

func almostEqual(v, w: Vec2[float]): bool =
  almostEqual(v.x, w.x) and almostEqual(v.y, w.y)

func abs[T](v: Vec2[T]): T =
  (x: abs v.x, y: abs v.y)

func magnitude[T](v: Vec2[T]): T =
  sqrt(v.x*v.x + v.y*v.y)

func rotate[T](v: Vec2[T], theta: float): Vec2[T] =
  (x: cos(theta)*v.x - sin(theta)*v.y, y: sin(theta)*v.x + cos(theta)*v.y)

func shearX[T](v: Vec2[T], phi: float): Vec2[T] =
  (x: cos(phi)*v.x - sin(phi)*v.y, y: v.y)

func `+`[T](v, w: Vec2[T]): Vec2[T] =
  (x: v.x + w.x, y: v.y + w.y)

func `-`[T](v, w: Vec2[T]): Vec2[T] =
  (x: v.x - w.x, y: v.y - w.y)

func `-`[T](v: Vec2[T]): Vec2[T] =
  (x: -v.x, y: -v.y)

func `*`[T](v, w: Vec2[T]): Vec2[T] =
  (x: v.x * w.x, y: v.y * w.y)

func `/`[T](v, w: Vec2[T]): Vec2[T] =
  (x: v.x / w.x, y: v.y / w.y)

func within(p: Vec2[SomeNumber], b: Rectangle): bool =
  return p.x >= b.x and p.x < b.x + b.w and p.y >= b.y and p.y < b.y + b.h

func withinUnit(p: Vec2[SomeNumber]): bool =
  within(p, UNIT)

func affineTransform(p: TexPoint2d, arg: AffineMatrix2d): TexPoint2d =
  return (x: p.x*arg[0] + p.y*arg[1] + arg[2], y: p.x*arg[3] + p.y*arg[4] + arg[5])

proc `*`(a: AffineMatrix2d, b: AffineMatrix2d): AffineMatrix2d =
  [a[0]*b[0] + a[1]*b[3], a[0]*b[1] + a[1]*b[4], a[0]*b[2] + a[1]*b[5] + a[2],
  a[3]*b[0] + a[4]*b[3], a[3]*b[1] + a[4]*b[4], a[3]*b[2] + a[4]*b[5] + a[5]]

proc `+`(a: AffineMatrix2d, b: AffineMatrix2d): AffineMatrix2d =
  [a[0]+b[0], a[1]+b[1], a[2]+b[2], a[3]+b[3], a[4]+b[4], a[5]+b[5]]

template rotationMatrix(theta: SomeNumber): AffineMatrix2d =
  [cos float theta, -sin float theta, 0.0, sin float theta, cos float theta, 0.0]

template shearMatrix(phi: SomeNumber, tau: SomeNumber): AffineMatrix2d =
  [1.0, tan float phi, 0.0, tan float tau, 1.0, 0.0]

template translateMatrix(x: SomeNumber, y: SomeNumber): AffineMatrix2d =
  [1.0, 0.0, float x, 0.0, 1.0, float y]

template scaleMatrix(w: SomeNumber, h: SomeNumber): AffineMatrix2d =
  [float w, 0.0, 0.0, 0.0, float h, 0.0]

template reflectYMatrix(): AffineMatrix2d =
  [-1.0, 0.0, 0.0, 0.0, 1.0, 0.0]

template reflectXMatrix(): AffineMatrix2d =
  [1.0, 0.0, 0.0, 0.0, -1.0, 0.0]

template reflectXYMatrix(): AffineMatrix2d =
  [-1.0, 0.0, 0.0, 0.0, -1.0, 0.0]

type SoftRenderer* = object
  currentFrame: int = 0
  renderLock: AtomicFlag
  buffer*: ptr PixBuf[CANVAS_WIDTH * CANVAS_HEIGHT]

var sren: ptr SoftRenderer = createShared SoftRenderer

proc setSren*(to: SoftRenderer): void =
  sren[] = to

proc cleanupGlobals*(): void =
  deallocShared sren

func lineIntersection(p,r,q,s: Vec2[float]): bool =
  let qp = q-p
  let rs = cross(r, s)
  let qpr = qp.cross r
  if rs.almostEqual(0):
    if qpr.almostEqual(0):
      return true # lines are colinear
    else:
      return false # lines are parallel
  else:
    let t = qp.cross(s)/rs
    let u = qpr/rs
    if 0 <= t and t <= 1 and 0 <= u and u <= 1:
      return true # lines intersect at p+tr=q+us
    else:
      return false # lines are neither parallel nor intersecting

func isPointInTriangle(c1,c2,c3,p: Vec2[float]): bool =
  let denominator = (c2.y-c3.y)*(c1.x-c3.x)+(c3.x-c2.x)*(c1.y-c3.y)
  let a = ((c2.y-c3.y)*(p.x-c3.x)+(c3.x-c2.x)*(p.y-c3.y)) / denominator
  let b = ((c3.y-c1.y)*(p.x-c3.x)+(c1.x-c3.x)*(p.y-c3.y)) / denominator
  let c = 1 - a - b
  return 0 <= a and a <= 1 and 0 <= b and b <= 1 and 0 <= c and c <= 1

func toParallelQuadSpace(p, origin, ver, hor, opposite: Vec2[SomeNumber]): Vec2[SomeNumber] =
  # find the transforms which relate the quad to the unit square
  # and then apply their inverse to the given point
  # rotation of horizontal line relative to X axis
  let theta = arccos(hor.x / hor.magnitude())
  # difference in rotation between horizontal and vertical lines (shear angle)
  let phi = arccos(ver.y / ver.magnitude()) - theta - (PI/4)
  return (p - origin).rotate(-theta).shearX(-phi) / (opposite - origin)

proc drawTile(p: PixelPoint2d): Color =
  let theta = (PI) * (float(tick[]) / 2000)
  let tp = toTexPoint2d(p, (x: 100, y: 80, w: 20, h: 20))
  let center: Vec2[float] = (x: 0, y: 0)
  let vecA: Vec2[float] = (x: sin(theta), y: -cos(theta))
  let vecB: Vec2[float] = (x: -cos(theta), y: -sin(theta))
  let vecC: Vec2[float] = (x: 0, y: 1)
  # segments 1&2, between A and B
  let corA = vecA + vecB
  if isPointInTriangle(center, vecA, corA, tp) or isPointInTriangle(center, vecB, corA, tp):
    return (a: 255, r: 255, g: 0, b: 0)
  # segments 3&4, between B and C
  let corB = vecB + vecC
  if isPointInTriangle(center, vecB, corB, tp) or isPointInTriangle(center, vecC, corB, tp):
    return (a: 255, r: 0, g: 255, b: 0)
  # segments 5&6, between C and A
  let corC = vecC + vecA
  if isPointInTriangle(center, vecC, corC, tp) or isPointInTriangle(center, vecA, corC, tp):
    return (a: 255, r: 0, g: 0, b: 255)
  # point not in tile
  return (a: 255, r: 64, g: 64, b: 64)

proc drawScene*(): void =
  #debug "drawing frame ", sren[].currentFrame
  if sren[].renderLock.testAndSet(): return
  var pixels = sren[].buffer
  for i in pixels[].low..pixels[].high:
    let x = i mod CANVAS_WIDTH
    let y = i div CANVAS_WIDTH
    pixels[][i] = toARGB(drawTile((x: x, y: y)))
    #pixels[][i] = toARGB((a: uint8 255, r: uint8 64, g: uint8 64, b: uint8 64))
    #pixels[][i] = uint32 0xffaaaaaa
  sren[].renderLock.clear()
