import streams
import rooms
import rendertypes
import logging

include "magicavox_default_palette.nim"

type 
  ChunkKind = enum
    main = ("MAIN")
    pack = ("PACK")
    size = ("SIZE")
    xyzi = ("XYZI")
    rgba = ("RGBA")
    ukwn = ("UKWN")
  Chunk = object
    contentLen: int32
    childLen: int32
    case kind: ChunkKind
    of main: main_ignored: void
    of pack: numModels: int32
    of size:
      sizeX: int32
      sizeY: int32
      sizeZ: int32
    of xyzi:
      numVoxels: int32
      voxels: seq[tuple[x, y, z, i: byte]]
    of rgba: palette: array[256, tuple[r, g, b, a: byte]]
    of ukwn: ukwn_ignored: void


proc checkHeader(strm: FileStream): bool =
  if readStr(strm, 4) == "VOX ":
    discard readInt32(strm)
    return true
  else: return false

proc readChunk(strm: FileStream): Chunk =
  var chunk = Chunk(
    kind: case readStr(strm, 4)
      of "MAIN": main
      of "PACK": pack
      of "SIZE": size
      of "XYZI": xyzi
      of "RGBA": rgba
      else: ukwn)
  if chunk.kind == ukwn: return chunk
  chunk.contentLen = readInt32 strm
  chunk.childLen = readInt32 strm
  case chunk.kind:
    of main: discard
    of pack: chunk.numModels = readInt32 strm
    of size:
      chunk.sizeX = readInt32 strm
      chunk.sizeY = readInt32 strm
      chunk.sizeZ = readInt32 strm
    of xyzi:
      chunk.numVoxels = readInt32 strm
      for _ in 1..chunk.numVoxels:
        chunk.voxels.add (x: readUint8(strm), y: readUint8(strm), z: readUint8(strm), i: readUint8(strm))
    of rgba:
      for index in 1..255:
        chunk.palette[index] = (r: readUint8(strm), g: readUint8(strm), b: readUint8(strm), a: readUint8(strm))
    of ukwn: discard
  return chunk

proc loadMagicaVox*(filename: string): Room =
  let loadlogger = newConsoleLogger()
  loadlogger.log(lvlDebug, "loading file ", filename)
  var strm = openFileStream("rooms/" & filename, fmRead)
  var chunks: seq[Chunk]
  var room: Room
  if not checkHeader(strm):
    loadlogger.log(lvlDebug, "invalid header")
    return room
  while not strm.atEnd:
    chunks.add(readChunk(strm))
  for chunk in chunks:
    case chunk.kind:
    of main: discard
    of pack: discard
    of size: discard
    of xyzi:
      for voxel in chunk.voxels:
        let col = default_palette[voxel.i]
        room.add(
          Voxel(
            point: (x: int voxel.x, y: int voxel.y, z: int voxel.z),
            faceA: toColor(col),
            faceB: toColor(col),
            faceC: toColor(col)#(p: TexPoint2d) => toColor(col).darken(if (p.x < 0.5 and p.y < 0.5) or (p.x >= 0.5 and p.y >= 0.5): 32 else: 40)
            ))
        loadlogger.log(lvlDebug, "loaded voxel: ", voxel)
    of rgba: discard
    of ukwn: discard
  loadlogger.log(lvlDebug, "loaded ", room.len, " voxels into room")
