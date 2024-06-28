import globals
import buffers
import atomics
import bitops
import math

type
  Color = tuple[a, r, g, b: uint8]
  Vec2[T] = tuple[x, y: T]
  Vec3[T] = tuple[x, y, z: T]
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

func toVec3[T](v: Vec2[T]): Vec3[T] =
  (x: v.x, y: v.y, z: 1)

func cross(v, w: Vec2[float]): Vec2[float] =
  (x: v.y - w.y, y: w.x - v.x)

func cross(v, w: Vec3[float]): Vec3[float] =
  (x: v.y*w.z - v.z*w.y, y: v.z*w.x - v.x*w.z, z: v.x*w.y - v.y*w.x)

func dot(v, w: Vec2[float]): float =
  v.x * w.x + v.y * w.y

func dot(v, w: Vec3[float]): float =
  v.x * w.x + v.y * w.y + v.z * w.z

func wedge(v, w: Vec2[float]): float =
  v.x * w.y - v.y * w.x

func almostEqual(v, w: Vec2[float], unitsInLastPlace: Natural = 4): bool =
  almostEqual(v.x, w.x, unitsInLastPlace) and almostEqual(v.y, w.y, unitsInLastPlace)

func abs[T](v: Vec2[T]): T =
  (x: abs v.x, y: abs v.y)

func magnitude[T](v: Vec2[T]): T =
  sqrt(v.x*v.x + v.y*v.y)

func rotate[T](v: Vec2[T], theta: float): Vec2[T] =
  (x: cos(theta)*v.x + sin(theta)*v.y, y: sin(theta)*v.x - cos(theta)*v.y)

func shearX[T](v: Vec2[T], phi: float): Vec2[T] =
  (x: v.x + ((cot(phi))*v.y), y: v.y)

func scale2[T](v: Vec2[T], dx, dy: float): Vec2[T] =
  (x: v.x * dx, y: v.y * dy)

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

func `+`[T](v, w: Vec3[T]): Vec3[T] =
  (x: v.x + w.x, y: v.y + w.y, z: v.z + w.z)

func `-`[T](v, w: Vec3[T]): Vec3[T] =
  (x: v.x - w.x, y: v.y - w.y, z: v.z - w.z)

func `-`[T](v: Vec3[T]): Vec3[T] =
  (x: -v.x, y: -v.y, z: -v.z)

func `*`[T](v, w: Vec3[T]): Vec3[T] =
  (x: v.x * w.x, y: v.y * w.y, z: v.z * w.z)

func `/`[T](v, w: Vec3[T]): Vec3[T] =
  (x: v.x / w.x, y: v.y / w.y, z: v.z / w.z)

func within(p: Vec2[SomeNumber], b: Rectangle): bool =
  return p.x >= b.x and p.x < b.x + b.w and p.y >= b.y and p.y < b.y + b.h

func withinUnit(p: Vec2[SomeNumber]): bool =
  return p.x >= 0 and p.x < 1 and p.y >= 0 and p.y < 1

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
  let rs = wedge(r, s)
  let qpr = qp.wedge r
  if rs.almostEqual(0):
    if qpr.almostEqual(0):
      return true # lines are colinear
    else:
      return false # lines are parallel
  else:
    let t = qp.wedge(s)/rs
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

func toParallelQuadSpace(p, origin, ver, hor: Vec2[SomeNumber]): Vec2[SomeNumber] =
  #[
    adapted from code in the following StackOverflow question:
    https://gamedev.stackexchange.com/q/198925
  ]#
  let
    P = origin.toVec3
    M = hor.toVec3 - P
    N = ver.toVec3 - P
    A = P.cross N
    B = M.cross P
    C = N.cross M
    S = p.toVec3
    a = S.dot A
    b = S.dot B
    c = S.dot C
    u = a / c
    v = b / c
  return (x: u, y: v)

proc drawTile(p: PixelPoint2d): Color =
  let theta = (2*PI) * (float(tick[]) / 1000)
  let tp = toTexPoint2d(p, (x: 100, y: 80, w: 20, h: 20))
  let center: Vec2[float] = (x: 0, y: 0)
  let vecA: Vec2[float] = (x: sin(theta), y: -cos(theta))
  let vecB: Vec2[float] = (x: -cos(theta), y: -sin(theta))
  let vecC: Vec2[float] = (x: 0, y: 1)
  # segments 1&2, between A and B
  if withinUnit(toParallelQuadSpace(tp, center, vecA, vecB)):
    return (a: 255, r: 255, g: 0, b: 0)
  # segments 3&4, between B and C
  if withinUnit(toParallelQuadSpace(tp, center, vecC, vecB)):
    return (a: 255, r: 0, g: 255, b: 0)
  # segments 5&6, between C and A
  if withinUnit(toParallelQuadSpace(tp, center, vecC, vecA)):
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

when isMainModule:
  let epsilon = 1e-15
  let sanityNear = toParallelQuadSpace((0.0,0.0), (0.0,0.0), (0.0,1.0), (1.0,0.0))
  let sanityHor = toParallelQuadSpace((1.0,0.0), (0.0,0.0), (0.0,1.0), (1.0,0.0))
  let sanityVer = toParallelQuadSpace((0.0,1.0), (0.0,0.0), (0.0,1.0), (1.0,0.0))
  let sanityFar = toParallelQuadSpace((1.0,1.0), (0.0,0.0), (0.0,1.0), (1.0,0.0))
  doAssert(abs(sanityNear.x - 0.0) < epsilon and abs(sanityNear.y - 0.0) < epsilon, $sanityNear)
  doAssert(abs(sanityHor.x - 1.0) < epsilon and abs(sanityHor.y - 0.0) < epsilon, $sanityHor)
  doAssert(abs(sanityVer.x - 0.0) < epsilon and abs(sanityVer.y - 1.0) < epsilon, $sanityVer)
  doAssert(abs(sanityFar.x - 1.0) < epsilon and abs(sanityFar.y - 1.0) < epsilon, $sanityFar)
