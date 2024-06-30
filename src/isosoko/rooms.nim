import rendertypes
import rtree
import math
import algorithm

type
  TilePoint* = Vec3[int]
  Voxel* = object
    point*: TilePoint
    faceA*: Color
    faceB*: Color
    faceC*: Color
    canvasPos*: tuple[center, vecA, vecB, vecC: Vec2[float]]
  Room* = seq[Voxel]
  RoomTree* = RStarTree[8, 2, float, Voxel]

proc preProcessVoxel(v: Voxel): Voxel =
  let theta = 1.2
  let height = 1.0
  let offset: Vec2[float] = (
    x: (sin(theta) * float v.point.x) + (-cos(theta) * float v.point.y),
    y: (-cos(theta) * float v.point.x) + (-sin(theta) * float v.point.y) - (height * float(v.point.z)))
  result = Voxel(
    point: v.point, faceA: v.faceA, faceB: v.faceB, faceC: v.faceC,
    canvasPos: (
      center: offset,
      vecA: (x: sin(theta), y: -cos(theta)) + offset,
      vecB: (x: -cos(theta), y: -sin(theta)) + offset,
      vecC: (x: 0.0, y: height) + offset
    )
  )

const testRoom*: Room = @[
  preProcessVoxel Voxel(point: (x: 0, y:1, z:0), faceA: (a: 255, r: 0, g: 0, b: 255), faceB: (a: 255, r: 0, g: 0, b: 255), faceC: (a: 255, r: 0, g: 0, b: 255)),
  preProcessVoxel Voxel(point: (x: 1, y:0, z:0), faceA: (a: 255, r: 0, g: 255, b: 0), faceB: (a: 255, r: 0, g: 255, b: 0), faceC: (a: 255, r: 0, g: 255, b: 0)),
  preProcessVoxel Voxel(point: (x: 0, y:0, z:0), faceA: (a: 255, r: 255, g: 0, b: 0), faceB: (a: 255, r: 255, g: 0, b: 0), faceC: (a: 255, r: 255, g: 0, b: 0)),
  preProcessVoxel Voxel(point: (x: 1, y:1, z:0), faceA: (a: 255, r: 255, g: 255, b: 255), faceB: (a: 255, r: 255, g: 255, b: 255), faceC: (a: 255, r: 255, g: 255, b: 255)),
  preProcessVoxel Voxel(point: (x: 2, y:1, z:0), faceA: (a: 255, r: 255, g: 0, b: 255), faceB: (a: 255, r: 255, g: 0, b: 255), faceC: (a: 255, r: 255, g: 0, b: 255)),
  preProcessVoxel Voxel(point: (x: 3, y:0, z:0), faceA: (a: 255, r: 255, g: 255, b: 0), faceB: (a: 255, r: 255, g: 255, b: 0), faceC: (a: 255, r: 255, g: 255, b: 0)),
  preProcessVoxel Voxel(point: (x: 2, y:0, z:0), faceA: (a: 255, r: 255, g: 0, b: 0), faceB: (a: 255, r: 255, g: 0, b: 0), faceC: (a: 255, r: 255, g: 0, b: 0)),
  preProcessVoxel Voxel(point: (x: 3, y:1, z:0), faceA: (a: 255, r: 255, g: 255, b: 255), faceB: (a: 255, r: 255, g: 255, b: 255), faceC: (a: 255, r: 255, g: 255, b: 255)),
  preProcessVoxel Voxel(point: (x: 0, y:3, z:0), faceA: (a: 255, r: 0, g: 255, b: 255), faceB: (a: 255, r: 0, g: 255, b: 255), faceC: (a: 255, r: 0, g: 255, b: 255)),
  preProcessVoxel Voxel(point: (x: 1, y:2, z:0), faceA: (a: 255, r: 0, g: 255, b: 0), faceB: (a: 255, r: 0, g: 255, b: 0), faceC: (a: 255, r: 0, g: 255, b: 0)),
  preProcessVoxel Voxel(point: (x: 0, y:2, z:0), faceA: (a: 255, r: 255, g: 255, b: 0), faceB: (a: 255, r: 255, g: 255, b: 0), faceC: (a: 255, r: 255, g: 255, b: 0)),
  preProcessVoxel Voxel(point: (x: 1, y:3, z:0), faceA: (a: 255, r: 255, g: 255, b: 255), faceB: (a: 255, r: 255, g: 255, b: 255), faceC: (a: 255, r: 255, g: 255, b: 255)),
  preProcessVoxel Voxel(point: (x: 2, y:3, z:0), faceA: (a: 255, r: 0, g: 0, b: 255), faceB: (a: 255, r: 0, g: 0, b: 255), faceC: (a: 255, r: 0, g: 0, b: 255)),
  preProcessVoxel Voxel(point: (x: 3, y:2, z:0), faceA: (a: 255, r: 0, g: 255, b: 255), faceB: (a: 255, r: 0, g: 255, b: 255), faceC: (a: 255, r: 0, g: 255, b: 255)),
  preProcessVoxel Voxel(point: (x: 2, y:2, z:0), faceA: (a: 255, r: 255, g: 0, b: 255), faceB: (a: 255, r: 255, g: 0, b: 255), faceC: (a: 255, r: 255, g: 0, b: 255)),
  preProcessVoxel Voxel(point: (x: 3, y:3, z:0), faceA: (a: 255, r: 255, g: 255, b: 255), faceB: (a: 255, r: 255, g: 255, b: 255), faceC: (a: 255, r: 255, g: 255, b: 255)),
  preProcessVoxel Voxel(point: (x: 1, y:1, z:1), faceA: (a: 255, r: 128, g: 128, b: 128), faceB: (a: 255, r: 128, g: 128, b: 128), faceC: (a: 255, r: 128, g: 128, b: 128)),
]

func distance(x, y: Voxel): int =
  cmp(x.point.x+x.point.y-x.point.z, y.point.x+y.point.y-y.point.z)

func box(v: Voxel): Box[2, float] =
  const dist = float(GRID_UNIT)
  result[0].a = (v.canvasPos.vecB.x * dist) + float(GRID_ORIGIN.x)
  result[0].b = (v.canvasPos.vecA.x * dist) + float(GRID_ORIGIN.x)
  result[1].a = ((v.canvasPos.vecA.y + v.canvasPos.vecB.y) * dist) + float(GRID_ORIGIN.y)
  result[1].b = (v.canvasPos.vecC.y * dist) + float(GRID_ORIGIN.y)

proc roomTree*(room: Room): RoomTree =
  result = newRStarTree[8, 2, float, Voxel]()
  for v in sorted(room, distance, Descending):
    let el: L[2, float, Voxel] = (b: box(v), l: v)
    result.insert(el)
    # echo el