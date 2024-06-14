import sdl2
import buffers
import globals

type
  SDLCanvas* = object
    buffer*: ptr PixBuf[CANVAS_WIDTH * CANVAS_HEIGHT]
    texture*: TexturePtr
    renderer*: RendererPtr
    window*: WindowPtr

proc initCanvas*(): ptr SDLCanvas =
  let window = createWindow(
    "test",
    SDL_WINDOWPOS_CENTERED,
    SDL_WINDOWPOS_CENTERED,
    CANVAS_WIDTH,
    CANVAS_HEIGHT,
    SDL_WINDOW_RESIZABLE)
  let renderer = createRenderer(window, -1, 0)
  let texture = createTexture(
    renderer,
    SDL_PIXELFORMAT_ARGB8888,
    SDL_TEXTUREACCESS_STREAMING,
    CANVAS_WIDTH,
    CANVAS_HEIGHT
  )
  let canvas = createShared(SDLCanvas)
  canvas[] = SDLCanvas(
    buffer: createShared PixBuf[CANVAS_WIDTH * CANVAS_HEIGHT],
    renderer: renderer,
    texture: texture,
    window: window
  )
  return canvas

proc destroyCanvas*(self: ptr SDLCanvas): void =
  destroyTexture self.texture
  destroyRenderer self.renderer
  destroyWindow self.window
  deallocShared self[].buffer
  deallocShared self
