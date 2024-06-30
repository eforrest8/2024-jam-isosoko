import globals
import buffers
import atomics
import math
import rooms
import rendertypes
import voxelloaders
import logging

type
  PixelPoint2d = Vec2[int]
  Rectangle = tuple[x, y, w, h: int]

proc toTexPoint2d(p: PixelPoint2d, bounds: Rectangle): TexPoint2d =
  return (x: float(p.x - bounds.x) / float(bounds.w), y: float(p.y - bounds.y) / float(bounds.h))

type SoftRenderer* = object
  currentFrame: int = 0
  renderLock: AtomicFlag
  buffer*: ptr PixBuf[CANVAS_WIDTH * CANVAS_HEIGHT]

let room: ptr Room = createShared(Room)
#room[] = loadMagicaVox("testroom.vox")
room[] = @[
  Voxel(point: (x: 0, y:1, z:0), faceA: (a: 255, r: 0, g: 0, b: 255), faceB: (a: 255, r: 0, g: 0, b: 255), faceC: (a: 255, r: 0, g: 0, b: 255)),
  Voxel(point: (x: 1, y:0, z:0), faceA: (a: 255, r: 0, g: 255, b: 0), faceB: (a: 255, r: 0, g: 255, b: 0), faceC: (a: 255, r: 0, g: 255, b: 0)),
  Voxel(point: (x: 0, y:0, z:0), faceA: (a: 255, r: 255, g: 0, b: 0), faceB: (a: 255, r: 255, g: 0, b: 0), faceC: (a: 255, r: 255, g: 0, b: 0)),
  Voxel(point: (x: 1, y:1, z:1), faceA: (a: 255, r: 255, g: 255, b: 255), faceB: (a: 255, r: 255, g: 255, b: 255), faceC: (a: 255, r: 255, g: 255, b: 255))
  ]
var sren: ptr SoftRenderer = createShared SoftRenderer

proc setSren*(to: SoftRenderer): void =
  sren[] = to

proc cleanupGlobals*(): void =
  deallocShared sren
  deallocShared room

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
  let tp = toTexPoint2d(p, (x: 100, y: 20, w: 20, h: 20))
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

func drawVoxel(v: Voxel, p: PixelPoint2d): Color =
  let theta = 1.2
  let tp = toTexPoint2d(p, (x: CANVAS_WIDTH div 2, y: CANVAS_HEIGHT - CANVAS_HEIGHT div 10, w: 20, h: 20))
  let height = 0.8
  let offset = (
    x: (sin(theta) * float v.point.x) + (-cos(theta) * float v.point.y),
    y: (-cos(theta) * float v.point.x) + (-sin(theta) * float v.point.y) - (height * float(v.point.z)))
  let center: Vec2[float] = offset
  let vecA: Vec2[float] = (x: sin(theta), y: -cos(theta)) + offset
  let vecB: Vec2[float] = (x: -cos(theta), y: -sin(theta)) + offset
  let vecC: Vec2[float] = (x: 0.0, y: height) + offset
  var ap: Vec2[float]
  # segments 1&2, between A and B
  ap = toParallelQuadSpace(tp, center, vecA, vecB)
  if withinUnit(ap):
    return v.faceA.darken(if ap.x < 0.1 or ap.y < 0.1 or ap.x > 0.9 or ap.y > 0.9: 128 else: 0)
  # segments 3&4, between B and C
  ap = toParallelQuadSpace(tp, center, vecC, vecB)
  if withinUnit(ap):
    return v.faceC.darken(if ap.x < 0.1 or ap.y < 0.1 or ap.x > 0.9 or ap.y > 0.9: 128 else: 64)
  # segments 5&6, between C and A
  ap = toParallelQuadSpace(tp, center, vecC, vecA)
  if withinUnit(ap):
    return v.faceB.darken(if ap.x < 0.1 or ap.y < 0.1 or ap.x > 0.9 or ap.y > 0.9: 128 else: 32)
  
  # point not in tile
  return (a: 0, r: 64, g: 64, b: 64)

proc drawRoom(room: Room, p: PixelPoint2d): Color =
  result = (a: 0, r: 64, g: 64, b: 64)
  for voxel in room.items:
    let color = drawVoxel(voxel, p)
    if color.a > 0:
      result = color

proc drawScene*(): void {.gcsafe.} =
  let logger = newConsoleLogger()
  #debug "drawing frame ", sren[].currentFrame
  if sren[].renderLock.testAndSet():
    #logger.log(lvlDebug, "ignoring draw request...")
    return
  var pixels = sren[].buffer
  for i in pixels[].low..pixels[].high:
    let x = i mod CANVAS_WIDTH
    let y = i div CANVAS_WIDTH
    pixels[][i] = toARGB(drawRoom(room[], (x: x, y: y)))
    #pixels[][i] = toARGB(drawTile((x: x, y: y)))
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
