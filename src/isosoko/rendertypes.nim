import math
import bitops
import globals

type
  Color* = tuple[a, r, g, b: uint8]
  Vec2*[T] = tuple[x, y: T]
  Vec3*[T] = tuple[x, y, z: T]
  TexPoint2d* = Vec2[float32]
  Renderer* = proc (p: TexPoint2d): Color

const GRID_UNIT*: int = 20
const GRID_ORIGIN*: tuple[x, y: int] = (CANVAS_WIDTH div 2, CANVAS_HEIGHT - CANVAS_HEIGHT div 10)

func toVec3*[T](v: Vec2[T]): Vec3[T] {.inline.} =
  (x: v.x, y: v.y, z: 1)

func cross*[T](v, w: Vec2[T]): Vec2[T] {.inline.} =
  (x: v.y - w.y, y: w.x - v.x)

func cross*[T](v, w: Vec3[T]): Vec3[T] {.inline.} =
  (x: v.y*w.z - v.z*w.y, y: v.z*w.x - v.x*w.z, z: v.x*w.y - v.y*w.x)

func dot*[T](v, w: Vec2[T]): T {.inline.} =
  v.x * w.x + v.y * w.y

func dot*[T](v, w: Vec3[T]): T {.inline.} =
  v.x * w.x + v.y * w.y + v.z * w.z

func wedge*[T](v, w: Vec2[T]): T {.inline.} =
  v.x * w.y - v.y * w.x

func almostEqual*(v, w: Vec2[SomeFloat], unitsInLastPlace: Natural = 4): bool {.inline.} =
  almostEqual(v.x, w.x, unitsInLastPlace) and almostEqual(v.y, w.y, unitsInLastPlace)

func abs*[T](v: Vec2[T]): T {.inline.} =
  (x: abs v.x, y: abs v.y)

func magnitude*[T](v: Vec2[T]): T {.inline.} =
  sqrt(v.x*v.x + v.y*v.y)

func `+`*[T](v, w: Vec2[T]): Vec2[T] {.inline.} =
  (x: v.x + w.x, y: v.y + w.y)

func `-`*[T](v, w: Vec2[T]): Vec2[T] {.inline.} =
  (x: v.x - w.x, y: v.y - w.y)

func `-`*[T](v: Vec2[T]): Vec2[T] {.inline.} =
  (x: -v.x, y: -v.y)

func `*`*[T](v, w: Vec2[T]): Vec2[T] {.inline.} =
  (x: v.x * w.x, y: v.y * w.y)

func `/`*[T](v, w: Vec2[T]): Vec2[T] {.inline.} =
  (x: v.x / w.x, y: v.y / w.y)

func `+`*[T](v, w: Vec3[T]): Vec3[T] {.inline.} =
  (x: v.x + w.x, y: v.y + w.y, z: v.z + w.z)

func `-`*[T](v, w: Vec3[T]): Vec3[T] {.inline.} =
  (x: v.x - w.x, y: v.y - w.y, z: v.z - w.z)

func `-`*[T](v: Vec3[T]): Vec3[T] {.inline.} =
  (x: -v.x, y: -v.y, z: -v.z)

func `*`*[T](v, w: Vec3[T]): Vec3[T] {.inline.} =
  (x: v.x * w.x, y: v.y * w.y, z: v.z * w.z)

func `*`*[T](v: Vec3[T], s: T): Vec3[T] {.inline.} =
  (x: v.x * s, y: v.y * s, z: v.z * s)

func `/`*[T](v, w: Vec3[T]): Vec3[T] {.inline.} =
  (x: v.x / w.x, y: v.y / w.y, z: v.z / w.z)

func withinUnit*(p: Vec2[SomeNumber]): bool {.inline.} =
  return p.x >= 0 and p.x < 1 and p.y >= 0 and p.y < 1

func toARGB*(self: Color): uint32 {.inline.} =
  return rotateLeftBits(uint32(self.a), 24).
    bitor(rotateLeftBits(uint32(self.r), 16)).
    bitor(rotateLeftBits(uint32(self.g), 8)).
    bitor(uint32(self.b))

func toColor*(self: uint32): Color {.inline.} =
  return (a: byte rotateRightBits(self, 24),
    r: byte rotateRightBits(self, 16),
    g: byte rotateRightBits(self, 8),
    b: byte self)

func darken*(self: Color, value: uint8): Color {.inline.} =
  (
    a: self.a,
    r: if self.r <= value: 0 else: self.r-value,
    g: if self.g <= value: 0 else: self.g-value,
    b: if self.b <= value: 0 else: self.b-value)
