import opencl
import nimcl

type
  Parallellogram {.packed.} = object
    pCornerX, pCornerY, pArmAX, pArmAY, pArmBX, pArmBY: float32
  Texture[W, H: static int] = array[W*H*4, uint8]
  TextureLibrary[W, H: static int] = seq[Texture[W, H]]
  TextureID = cint
  Drawable {.packed.} = object
    prim: Parallellogram
    tex: TextureID

var testLibrary: TextureLibrary[4,4] = @[
  [ 255,255,0,0, 255,255,0,0, 255,255,0,0, 255,255,0,0,
    255,255,0,0, 255,255,255,0, 255,255,255,0, 255,255,0,0,
    255,255,0,0, 255,255,255,0, 255,255,255,0, 255,255,0,0,
    255,255,0,0, 255,255,0,0, 255,255,0,0, 255,255,0,0,],
  [ 255,0,0,255, 255,0,0,255, 255,0,0,255, 255,0,0,255,
    255,0,0,255, 255,0,255,255, 255,0,255,255, 255,0,0,255,
    255,0,0,255, 255,0,255,255, 255,0,255,255, 255,0,0,255,
    255,0,0,255, 255,0,0,255, 255,0,0,255, 255,0,0,255]
]

var pixBuf: ptr array[100*100*4, uint8] = cast[ptr array[100*100*4, uint8]](alloc(sizeof(uint8)*100*100*4))

var testDrawables = @[
  Drawable(prim: Parallellogram(
    pCornerX: 0.0, pCornerY: 0.0,
    pArmAX: 12.0, pArmAY: 0.0,
    pArmBX: 0.0, pArmBY: 12.0), tex: 1),
  Drawable(prim: Parallellogram(
    pCornerX: 50.0, pCornerY: 50.0,
    pArmAX: -12.0, pArmAY: 12.0,
    pArmBX: 12.0, pArmBY: 12.0), tex: 0)
]

proc loadTextures(context: Pcontext, lib: TextureLibrary): Pmem =
  var status: TClResult
  let
    format: ptr Timage_format = create(Timage_format)
    desc: ptr Timage_desc = create(Timage_desc)
    buf = context.bufferLike(lib)
  format[].image_channel_order = CL_ARGB
  format[].image_channel_data_type = CL_UNSIGNED_INT8
  desc[].image_height = lib.H
  desc[].image_type = MEM_OBJECT_IMAGE2D
  desc[].image_width = lib.W
  let
    img = context.createImage(
      MEM_READ_ONLY,
      format,
      desc,
      nil,
      addr status)
  check status
  return img

const clSource = staticRead("drawquad.cl")

proc drawScene*(): void =
  var status: TClResult
  let
    (device, context, queue) = singleDeviceDefaults()
    program = context.createAndBuild(clSource, device)
    colorAt = program.createKernel("color_at")
    texArray = context.bufferLike(testLibrary)
    drawables = context.bufferLike(testDrawables)
    output = context.createBuffer(MEM_READ_WRITE, 100*100*4, nil, addr status)
  try:
    colorAt.args(texArray, drawables, cint testDrawables.len(), output, 100'i32, 100'i32)
    queue.write(testLibrary, texArray)
    queue.write(testDrawables, drawables)
    queue.run(colorAt, 100*100)
    queue.read(pixBuf, output, 100*100*4)
    var outfile = open("cltestout.pam", fmReadWrite)
    discard writeChars(outfile, "P7\n".toOpenArray(0, 2), 0, 3)
    discard writeChars(outfile, "WIDTH 100\n".toOpenArray(0, 9), 0, 10)
    discard writeChars(outfile, "HEIGHT 100\n".toOpenArray(0, 10), 0, 11)
    discard writeChars(outfile, "DEPTH 4\n".toOpenArray(0, 7), 0, 8)
    discard writeChars(outfile, "MAXVAL 255\n".toOpenArray(0, 10), 0, 11)
    discard writeChars(outfile, "TUPLTYPE RGB_ALPHA\n".toOpenArray(0, 18), 0, 19)
    discard writeChars(outfile, "ENDHDR\n".toOpenArray(0, 6), 0, 7)
    discard writeBuffer(outfile, pixBuf, 100*100*4)
    close(outfile)
  finally:
    release queue
    release program
    release context
    release colorAt
    release texArray
    release drawables
    release output

proc main() =
  const
    body = staticRead("drawquad.cl")
    size = 1_000_000
  var
    a = newSeq[float32](size)
    b = newSeq[float32](size)
    c = newSeq[float32](size)

  for i in 0 .. a.high:
    a[i] = i.float32
    b[i] = i.float32

  let
    (device, context, queue) = singleDeviceDefaults()
    program = context.createAndBuild(body, device)
    add = program.createKernel("add_vector")
    gpuA = context.bufferLike(a)
    gpuB = context.bufferLike(b)
    gpuC = context.bufferLike(c)

  add.args(gpuA, gpuB, gpuC, size.int32)

  queue.write(a, gpuA)
  queue.write(b, gpuB)
  queue.run(add, size)
  queue.read(c, gpuC)

  echo c[1 .. 100]

  # Clean up
  release(queue)
  release(add)
  release(program)
  release(gpuA)
  release(gpuB)
  release(gpuC)
  release(context)

when isMainModule:
  drawScene()
