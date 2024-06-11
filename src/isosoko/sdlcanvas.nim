import sdl2
import buffers
import globals

type
  SDLCanvas* = object
    buffer*: SwappableBuffer[CANVAS_WIDTH * CANVAS_HEIGHT]
    texture*: TexturePtr
    renderer*: RendererPtr
    window*: WindowPtr
    swap*: proc(self: var SDLCanvas)

proc initCanvas*(): SDLCanvas =
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
  return SDLCanvas(
    renderer: renderer,
    texture: texture,
    window: window,
    swap: proc (s: var SDLCanvas) = swap s.buffer
  )

proc destroyCanvas*(self: SDLCanvas): void =
  destroyTexture self.texture
  destroyRenderer self.renderer
  destroyWindow self.window
