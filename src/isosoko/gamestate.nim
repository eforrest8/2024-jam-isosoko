import locks

type
  GraphicKind = enum
    billboard, voxel
  Facing = enum
    north, east, south, west
  Shape = set[uint8]
  Color = tuple[r, g, b: uint8]
  Texture = seq[Color]
  Graphic = ref object
    case kind: GraphicKind
      of billboard: tex: Texture
      of voxel: topTex, frontTex, sideTex: Texture
  Point* = tuple[x, y, z: int]
  Actor* = object of RootObj
    position: Point
    size: Point
    shape: Shape
    facing: Facing
    graphic: Graphic
  Block* = tuple[solid: bool, texture: Texture]
  TileLayout* = tuple[size: Point, tiles: seq[Block]]
  Room* = object
    layout: TileLayout
    actors: seq[Actor]
    title: string
  
  Player = object of Actor
  Box = object of Actor
  Tornado = object of Actor

let t1: Texture = @[]
let testRoom: Room = Room(
  layout: (size: (x: 2, y: 1, z: 2), tiles: @[
    (solid: true, texture: t1),
    (solid: true, texture: t1),
    (solid: true, texture: t1),
    (solid: false, texture: t1)]),
  actors: @[],
  title: "Test Room"
)

var stateLock: Lock = Lock()

proc getState*(): Room =
  withLock stateLock:
    return testRoom