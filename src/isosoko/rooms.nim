import rendertypes

type
  TilePoint* = Vec3[int]
  Voxel* = object
    point*: TilePoint
    faceA*: Color
    faceB*: Color
    faceC*: Color
  Room* = seq[Voxel]
