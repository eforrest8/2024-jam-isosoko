import globals
import buffers
import atomics
import math
import rooms
import rendertypes
import voxelloaders
import logging
import rtree
import os
import std/monotimes
import malebolgia
from sdl2 import pushEvent, UserEventPtr, UserEventObj, EventType, Event

type
  PixelPoint2d = Vec2[int]
  Rectangle = tuple[x, y, w, h: int]

proc toTexPoint2d(p: PixelPoint2d, bounds: Rectangle): TexPoint2d =
  return (x: float(p.x - bounds.x) / float(bounds.w), y: float(p.y - bounds.y) / float(bounds.h))

type SoftRenderer* = object
  currentFrame: int = 0
  renderLock: AtomicFlag
  buffer*: ptr PixBuf[CANVAS_WIDTH * CANVAS_HEIGHT]

let room: ptr RoomTree = createShared(RoomTree)
#room[] = loadMagicaVox("testroom.vox")
room[] = roomTree(testRoom)
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

func drawVoxel(v: Voxel, p: PixelPoint2d): Color =
  let tp = toTexPoint2d(p, (x: GRID_ORIGIN.x, y: GRID_ORIGIN.y, w: GRID_UNIT, h: GRID_UNIT))
  var ap: Vec2[float]
  # top, between A and B
  ap = toParallelQuadSpace(tp, v.canvasPos.center, v.canvasPos.vecA, v.canvasPos.vecB)
  if withinUnit(ap):
    return v.faceA.darken(if ap.x < 0.1 or ap.y < 0.1 or ap.x > 0.9 or ap.y > 0.9: 128 else: 0)
  # darker side, between B and C
  ap = toParallelQuadSpace(tp, v.canvasPos.center, v.canvasPos.vecC, v.canvasPos.vecB)
  if withinUnit(ap):
    return v.faceC.darken(if ap.x < 0.1 or ap.y < 0.1 or ap.x > 0.9 or ap.y > 0.9: 128 else: 64)
  # lighter side, between C and A
  ap = toParallelQuadSpace(tp, v.canvasPos.center, v.canvasPos.vecC, v.canvasPos.vecA)
  if withinUnit(ap):
    return v.faceB.darken(if ap.x < 0.1 or ap.y < 0.1 or ap.x > 0.9 or ap.y > 0.9: 128 else: 32)
  # point not in tile
  return (a: 0, r: 64, g: 64, b: 64)

proc drawRoom(room: RoomTree, p: PixelPoint2d): Color =
  result = (a: 0, r: 64, g: 64, b: 64)
  let found = room.search([(a: float p.x, b: float p.x), (a: float p.y, b: float p.y)])
  for res in found:
    let color = drawVoxel(res.l, p)
    if color.a > 0:
      result = color

proc drawScene*(): void {.gcsafe.} =
  var m = createMaster()
  #let logger = newConsoleLogger()
  #debug "drawing frame ", sren[].currentFrame
  if sren[].renderLock.testAndSet():
    #logger.log(lvlDebug, "ignoring draw request...")
    return
  var pixels = sren[].buffer
  m.awaitAll:
    for i in pixels[].low..pixels[].high:
      let x = i mod CANVAS_WIDTH
      let y = i div CANVAS_WIDTH
      m.spawn toARGB(drawRoom(room[], (x: x, y: y))) -> pixels[][i]
      #pixels[][i] = toARGB(drawTile((x: x, y: y)))
      #pixels[][i] = toARGB((a: uint8 255, r: uint8 64, g: uint8 64, b: uint8 64))
      #pixels[][i] = uint32 0xffaaaaaa
  let ev: UserEventPtr = create UserEventObj
  ev[].kind = UserEvent
  ev[].code = 0
  discard pushEvent(cast [ptr Event](ev))
  sren[].renderLock.clear()

proc renderLoop*(): void =
  while true:
    drawScene()
    os.sleep(10)

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
