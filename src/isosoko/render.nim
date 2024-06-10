import sdl2
#import typedthreads

type
  PixBuf[S] = array[S,uint32]

const CANVAS_WIDTH = 320
const CANVAS_HEIGHT = 240
const PIXEL_SIZE = sizeof(uint32)

var go: bool = true

proc handleEvents(): void =
  var quit = false
  while go:
    var event: Event
    discard waitEvent(event)
    case event.kind:
      of QuitEvent:
        quit = true
      else:
        break

proc drawScene(args: tuple[renderer: RendererPtr, texture: TexturePtr]): void =
  let (renderer, texture) = args
  var pixels: PixBuf[CANVAS_WIDTH * CANVAS_HEIGHT]
  while go:
    updateTexture(texture, nil, addr pixels, CANVAS_WIDTH * PIXEL_SIZE)
    clear(renderer)
    copy(renderer, texture, nil, nil)
    present(renderer)
  # end

proc main(): void =
  assert init(INIT_VIDEO).toBool
  let window: WindowPtr = createWindow(
    "test",
    SDL_WINDOWPOS_CENTERED,
    SDL_WINDOWPOS_CENTERED,
    CANVAS_WIDTH,
    CANVAS_HEIGHT,
    0)
  let renderer = createRenderer(window, -1, 0)
  let texture = createTexture(
    renderer,
    SDL_PIXELFORMAT_ARGB8888,
    SDL_TEXTUREACCESS_STATIC,
    CANVAS_WIDTH,
    CANVAS_HEIGHT)
  var eventThread: Thread[void]
  var drawThread: Thread[tuple[renderer: RendererPtr, texture: TexturePtr]]
  createThread(eventThread, handleEvents)
  createThread(drawThread, drawScene, (renderer, texture))
  destroyWindow(window)
  sdl2.quit()
