import opencl
import nimcl
import ../globals
import atomics
import ../buffers
import random

type
  Parallellogram {.packed.} = object
    pCornerX, pCornerY, pArmAX, pArmAY, pArmBX, pArmBY: float32
  Texture[W, H: static int] = array[W*H*4, uint8]
  TextureLibrary[W, H: static int] = seq[Texture[W, H]]
  TextureID = cint
  Drawable {.packed.} = object
    prim: Parallellogram
    tex: TextureID
  SoftRenderer* = object
    currentFrame: int = 0
    renderLock: AtomicFlag
    buffer*: ptr PixBuf[CANVAS_WIDTH * CANVAS_HEIGHT]

var sren: ptr SoftRenderer = createShared SoftRenderer

proc setSren*(to: SoftRenderer): void =
  sren[] = to
proc cleanupGlobals*(): void =
  deallocShared sren

var testLibrary: TextureLibrary[4,4] = @[
  [ 255,255,0,0, 255,255,0,0, 255,255,0,0, 255,255,0,0,
    255,255,0,0, 255,255,255,0, 255,255,255,0, 255,255,0,0,
    255,255,0,0, 255,255,255,0, 255,255,255,0, 255,255,0,0,
    255,255,0,0, 255,255,0,0, 255,255,0,0, 255,255,0,0,],
  [ 255,0,0,255, 255,0,0,255, 255,0,0,255, 255,0,0,255,
    255,0,0,255, 255,0,255,255, 255,0,255,255, 255,0,0,255,
    255,0,0,255, 255,0,255,255, 255,0,255,255, 255,0,0,255,
    255,0,0,255, 255,0,0,255, 255,0,0,255, 255,0,0,255],
  [ 255,  0,  0,255, 255, 64, 64,255, 255,  0,  0,255, 255, 64, 64,255,
    255, 64, 64,255, 255,  0,  0,255, 255, 64, 64,255, 255,  0,  0,255,
    255,  0,  0,255, 255, 64, 64,255, 255,  0,  0,255, 255, 64, 64,255,
    255, 64, 64,255, 255,  0,  0,255, 255, 64, 64,255, 255,  0,  0,255],
  [ 255,192,192,192, 255, 64, 64, 64, 255,192,192,192, 255, 64, 64, 64,
    255, 64, 64, 64, 255,192,192,192, 255, 64, 64, 64, 255,192,192,192,
    255,192,192,192, 255, 64, 64, 64, 255,192,192,192, 255, 64, 64, 64,
    255, 64, 64, 64, 255,192,192,192, 255, 64, 64, 64, 255,192,192,192]
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
  desc[].image_type = MEM_OBJECT_IMAGE2D_ARRAY
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
const TEST_DRAWABLE_COUNT = 1_000_000

proc generateTestDrawables(count: int): seq[Drawable] =
  for i in 1..count:
    result.add(Drawable(
      prim: Parallellogram(
        pCornerX: rand(float32 CANVAS_WIDTH), pCornerY: rand(float32 CANVAS_HEIGHT),
        pArmAX: rand(-50.0..50.0), pArmAY: rand(-50.0..50.0),
        pArmBX: rand(-50.0..50.0), pArmBY: rand(-50.0..50.0)
      ),
      tex: int32 rand(testLibrary.high)
    ))

var status: TClResult
var testDrawables = generateTestDrawables(TEST_DRAWABLE_COUNT)
let
  (device, context, queue) = singleDeviceDefaults()
  program = context.createAndBuild(clSource, device)
  colorAt = program.createKernel("color_at")
  texArray = context.bufferLike(testLibrary)
  drawables = context.bufferLike(testDrawables)
  output = context.createBuffer(MEM_READ_WRITE, CANVAS_WIDTH * CANVAS_HEIGHT * 4, nil, addr status)
check status
queue.write(testLibrary, texArray)
queue.write(testDrawables, drawables)

proc drawScene*(): void {.gcsafe.} =
  if sren[].renderLock.testAndSet():
    return
  try:
    colorAt.args(texArray, drawables, cint TEST_DRAWABLE_COUNT, output, cint CANVAS_WIDTH, cint CANVAS_HEIGHT)
    #queue.write(testDrawables, drawables)
    queue.run(colorAt, CANVAS_WIDTH * CANVAS_HEIGHT)
    #check enqueueReadBuffer(queue, output, CL_TRUE, 0, sren[].buffer[].len(), sren[].buffer, 0, nil, nil)
    queue.read(sren[].buffer, output, sren[].buffer[].len() * 4)
  except EOpenCL as e:
    echo e.getStackTrace()
  finally:
    clear sren[].renderLock
    #release drawables

proc releaseRenderer*(): void =
  release queue
  release program
  release context
  release colorAt
  release drawables
  release texArray
  release output
