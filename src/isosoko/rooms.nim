import rendertypes
import math
import algorithm

type
  TilePoint* = Vec3[int]
  Voxel* = object
    point*: TilePoint
    faceA*: Color
    faceB*: Color
    faceC*: Color
    center*: Vec2[float32]
  Room* = seq[Voxel]

proc preProcessVoxel(v: Voxel): Voxel =
  let theta = 1.2
  let height = 1.0
  let offset: Vec2[float32] = (
    x: float32 (sin(theta) * float32 v.point.x) + (-cos(theta) * float32 v.point.y),
    y: float32 (-cos(theta) * float32 v.point.x) + (-sin(theta) * float32 v.point.y) - (height * float32(v.point.z)))
  result = Voxel(
    point: v.point, faceA: v.faceA, faceB: v.faceB, faceC: v.faceC,
    center: offset
  )

### measures distance from camera
### camera is placed at -inf x, -inf y, inf z
func `<`*(a, b: Voxel): bool {.inline.} =
  a.point.x-a.point.z < b.point.x-b.point.z or a.point.y-a.point.z < b.point.y-b.point.z or a.point.z > b.point.z

func `==`*(a, b: Voxel): bool {.inline.} =
  a.point.x == b.point.x and a.point.y == b.point.y and a.point.z == b.point.z

const testRoom*: Room = sorted @[
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

const testRoom2*: Room = sorted @[
  preProcessVoxel Voxel(point: (x: 1, y:1, z:1), faceA: (a: 255, r: 128, g: 128, b: 128), faceB: (a: 255, r: 128, g: 128, b: 128), faceC: (a: 255, r: 128, g: 128, b: 128)),
]
const testRoom3*: Room = sorted @[
  preProcessVoxel Voxel(point: (x: 1, y:1, z:1), faceA: (a: 255, r: 255, g: 128, b: 128), faceB: (a: 255, r: 255, g: 128, b: 128), faceC: (a: 255, r: 255, g: 128, b: 128)),
]
