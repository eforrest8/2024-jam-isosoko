import globals
import buffers
import atomics
import math
import rooms
import rendertypes
import os
import malebolgia
import options
import nimsimd/sse2
import nimsimd/runtimecheck

type
  PixelPoint2d = Vec2[int]
  Rectangle = tuple[x, y, w, h: int]

proc toTexPoint2d(p: PixelPoint2d, bounds: Rectangle): TexPoint2d =
  return (x: float32(p.x - bounds.x) / float32(bounds.w), y: float32(p.y - bounds.y) / float32(bounds.h))

type SoftRenderer* = object
  currentFrame: int = 0
  renderLock: AtomicFlag
  buffer*: ptr PixBuf[CANVAS_WIDTH * CANVAS_HEIGHT]

let room: ptr Room = createShared(Room)
#room[] = loadMagicaVox("testroom.vox")
room[] = testRoom
let room2: ptr Room = createShared(Room)
room2[] = testRoom3
var sren: ptr SoftRenderer = createShared SoftRenderer

proc setSren*(to: SoftRenderer): void =
  sren[] = to

proc cleanupGlobals*(): void =
  deallocShared sren
  deallocShared room

##[
  Assumes that lines are never parallel or collinear.
  Returns the distance along the line pr at which
  intersection occurs. Values outside the range 0-1
  indicate intersection outside the line segment.
]##
func fastLineIntersection(x1,x2,x3,x4, y1,y2,y3,y4: float32): Vec2[float32] =
  #[var buf = [
    x1, x1, y1, y1,
    x2, x3, y2, y3,
    y3, y3, x3, x3,
    y4, y4, x4, x4]
  mm_storeu_ps(addr(buf[0]), mm_sub_ps(mm_loadu_ps(addr(buf[0])), mm_loadu_ps(addr(buf[4]))))
  mm_storeu_ps(addr(buf[4]), mm_sub_ps(mm_loadu_ps(addr(buf[8])), mm_loadu_ps(addr(buf[12]))))
  #[
    x1m2, y1m2, x1m3, y1m3,
    y3m4, y3m4, x3m4, x3m4,
    -[0], -[2], ----, ----,
    -[3], -[1], ----, ----
  ]#
  buf[8] = buf[0]
  buf[9] = buf[2]
  buf[12] = buf[3]
  buf[13] = buf[1]
  mm_storeu_ps(addr(buf[0]), mm_mul_ps(mm_loadu_ps(addr(buf[0])), mm_loadu_ps(addr(buf[4]))))
  mm_storeu_ps(addr(buf[6]), mm_mul_ps(mm_loadu_ps(addr(buf[8])), mm_loadu_ps(addr(buf[12]))))
  #[
    x1m2*y3m4, x1m3*y3m4, y1m2*x3m4, y1m3*x3m4,
    ---------, ---------, x1m2*y1m3, y1m2*x1m3,
    ------[0], ------[1], ---------, ------[6],
    ------[2], ------[3], ---------, ---------
  ]#
  buf[4] = buf[2]
  buf[5] = buf[3]
  buf[3] = buf[6]
  mm_storeu_ps(addr(buf[0]), mm_sub_ps(mm_loadu_ps(addr(buf[0])), mm_loadu_ps(addr(buf[4]))))
  #[
    d, xn, -, -yn
  ]#
  mm_storeu_ps(addr(buf[0]), mm_div_ps(mm_loadu_ps(addr(buf[0])), mm_set1_ps(buf[0])))
  #[
    -, x, -, -y
  ]#
  return (x: buf[1], y: -buf[3])]#
  #[else:
    let
      x1m2 = x1-x2
      x1m3 = x1-x3
      x3m4 = x3-x4
      y1m2 = y1-y2
      y1m3 = y1-y3
      y3m4 = y3-y4
      d = x1m2 * y3m4 - y1m2 * x3m4
    return (
      x: (x1m3 * y3m4 - y1m3 * x3m4) / d,
      y: -(x1m2 * y1m3 - y1m2 * x1m3) / d)]#
  return (
      x: ((x1-x3) * (y3-y4) - (y1-y3) * (x3-x4)) / ((x1-x2) * (y3-y4) - (y1-y2) * (x3-x4)),
      y: -((x1-x2) * (y1-y3) - (y1-y2) * (x1-x3)) / ((x1-x2) * (y3-y4) - (y1-y2) * (x3-x4)))

func fastLineIntersection(p,r,q,s: Vec2[float32]): Vec2[float32] {.inline.} =
  fastLineIntersection(p.x, r.x, q.x, s.x, p.y, r.y, q.y, s.y)

##[
## Convert a point to quad space, suitable for texture mapping.
]##
func toParallelQuadSpace(point, origin, armA, armB: Vec2[float32]): Vec2[float32] =
  return fastLineIntersection(origin, armB+origin, point, point-armA)

func isPointInTriangle(c1,c2,c3,p: Vec2[float32]): bool =
  let denominator = (c2.y-c3.y)*(c1.x-c3.x)+(c3.x-c2.x)*(c1.y-c3.y)
  let a = ((c2.y-c3.y)*(p.x-c3.x)+(c3.x-c2.x)*(p.y-c3.y)) / denominator
  let b = ((c3.y-c1.y)*(p.x-c3.x)+(c1.x-c3.x)*(p.y-c3.y)) / denominator
  let c = 1 - a - b
  return 0 <= a and a <= 1 and 0 <= b and b <= 1 and 0 <= c and c <= 1

const THETA: float32 = 1.2
const HEIGHT: float32 = 1.0
const PERSPECTIVE_A: Vec2[float32] = (x: float32 sin(THETA), y: float32 -cos(THETA))
const PERSPECTIVE_B: Vec2[float32] = (x: float32 -cos(THETA), y: float32 -sin(THETA))
const PERSPECTIVE_C: Vec2[float32] = (x: float32 0.0, y: HEIGHT)

func drawVoxel(v: Voxel, p: PixelPoint2d): Color =
  let tp = toTexPoint2d(p, (x: GRID_ORIGIN.x, y: GRID_ORIGIN.y, w: GRID_UNIT, h: GRID_UNIT))
  var ap: Vec2[float32]
  # top, between A and B
  ap = toParallelQuadSpace(tp, v.center, PERSPECTIVE_A, PERSPECTIVE_B)
  if withinUnit(ap):
    return v.faceA.darken(if ap.x < 0.1 or ap.y < 0.1 or ap.x > 0.9 or ap.y > 0.9: 128 else: 0)
  # darker side, between B and C
  ap = toParallelQuadSpace(tp, v.center, PERSPECTIVE_C, PERSPECTIVE_B)
  if withinUnit(ap):
    return v.faceC.darken(if ap.x < 0.1 or ap.y < 0.1 or ap.x > 0.9 or ap.y > 0.9: 128 else: 64)
  # lighter side, between C and A
  ap = toParallelQuadSpace(tp, v.center, PERSPECTIVE_C, PERSPECTIVE_A)
  if withinUnit(ap):
    return v.faceB.darken(if ap.x < 0.1 or ap.y < 0.1 or ap.x > 0.9 or ap.y > 0.9: 128 else: 32)
  # point not in tile
  return (a: 0, r: 64, g: 64, b: 64)

func minOf[T](nums: varargs[T]): T =
  result = nums[0]
  for n in nums:
    result = min(n, result)

func maxOf[T](nums: varargs[T]): T =
  result = nums[0]
  for n in nums:
    result = max(n, result)

proc drawRoom(room: ptr Room, p: PixelPoint2d): Color =
  #var found: seq[L[2, system.float, rooms.Voxel]] = room.search([(a: float p.x, b: float p.x), (a: float p.y, b: float p.y)])
  #sort(found, proc (x, y: L[2, system.float, rooms.Voxel]): int {.closure.}= cmp(x.l, y.l))
  for res in room[]:
    let color = drawVoxel(res, p)
    if color.a > 0:
      return color
  return (a: 255, r: 64, g: 64, b: 64)

proc drawScene*(mo: Option[MasterHandle] = none(MasterHandle)): void {.gcsafe.} =
  if sren[].renderLock.testAndSet():
    return
  let curRoom = if tick[] mod 2 == 0: room else: room2
  var pixels = sren[].buffer
  if mo.isNone:
    for i in pixels[].low..pixels[].high:
      let x = i mod CANVAS_WIDTH
      let y = i div CANVAS_WIDTH
      pixels[][i] = toARGB(drawRoom(curRoom, (x: x, y: y)))
  else:
    let mh = mo.get()
    for i in pixels[].low..pixels[].high:
      let x = i mod CANVAS_WIDTH
      let y = i div CANVAS_WIDTH
      mh.spawn toARGB(drawRoom(curRoom, (x: x, y: y))) -> pixels[][i]
  tick[] += 1
  sren[].renderLock.clear()

proc renderLoop*(): void =
  while true:
    drawScene()
    os.sleep(10)

when isMainModule:
  let epsilon = 1e-15
  let sanityNear = toParallelQuadSpace((float32 0.0,float32 0.0), (float32 0.0,float32 0.0), (float32 0.0,float32 1.0), (float32 1.0,float32 0.0))
  let sanityHor = toParallelQuadSpace((float32 1.0,float32 0.0), (float32 0.0,float32 0.0), (float32 0.0,float32 1.0), (float32 1.0,float32 0.0))
  let sanityVer = toParallelQuadSpace((float32 0.0,float32 1.0), (float32 0.0,float32 0.0), (float32 0.0,float32 1.0), (float32 1.0,float32 0.0))
  let sanityFar = toParallelQuadSpace((float32 1.0,float32 1.0), (float32 0.0,float32 0.0), (float32 0.0,float32 1.0), (float32 1.0,float32 0.0))
  doAssert(abs(sanityNear.x - 0.0) < epsilon and abs(sanityNear.y - 0.0) < epsilon, $sanityNear)
  doAssert(abs(sanityHor.x - 1.0) < epsilon and abs(sanityHor.y - 0.0) < epsilon, $sanityHor)
  doAssert(abs(sanityVer.x - 0.0) < epsilon and abs(sanityVer.y - 1.0) < epsilon, $sanityVer)
  doAssert(abs(sanityFar.x - 1.0) < epsilon and abs(sanityFar.y - 1.0) < epsilon, $sanityFar)
  let offsetNear = toParallelQuadSpace((float32 1.0,float32 1.0), (float32 1.0,float32 1.0), (float32 0.0,float32 1.0), (float32 1.0,float32 0.0))
  let offsetHor =  toParallelQuadSpace((float32 2.0,float32 1.0), (float32 1.0,float32 1.0), (float32 0.0,float32 1.0), (float32 1.0,float32 0.0))
  let offsetVer =  toParallelQuadSpace((float32 1.0,float32 2.0), (float32 1.0,float32 1.0), (float32 0.0,float32 1.0), (float32 1.0,float32 0.0))
  let offsetFar =  toParallelQuadSpace((float32 2.0,float32 2.0), (float32 1.0,float32 1.0), (float32 0.0,float32 1.0), (float32 1.0,float32 0.0))
  doAssert(abs(offsetNear.x - 0.0) < epsilon and abs(offsetNear.y - 0.0) < epsilon, $offsetNear)
  doAssert(abs(offsetHor.x - 1.0) < epsilon and abs(offsetHor.y - 0.0) < epsilon, $offsetHor)
  doAssert(abs(offsetVer.x - 0.0) < epsilon and abs(offsetVer.y - 1.0) < epsilon, $offsetVer)
  doAssert(abs(offsetFar.x - 1.0) < epsilon and abs(offsetFar.y - 1.0) < epsilon, $offsetFar)
  let transformedInside = toParallelQuadSpace((float32 0.0,float32 1.0), (float32 0.0,float32 0.0), (float32 -1.0,float32 1.0), (float32 1.0,float32 1.0))
  doAssert(abs(transformedInside.x - 0.5) < epsilon and abs(transformedInside.y - 0.5) < epsilon, $transformedInside)
