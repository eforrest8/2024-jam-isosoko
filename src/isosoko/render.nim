import sdl2
import logging

type
  PixBuf[S: static int] = array[S,uint32]

const CANVAS_WIDTH = 320
const CANVAS_HEIGHT = 240
const PIXEL_SIZE = sizeof(uint32)

var logger = newConsoleLogger()
addHandler logger

proc handleEvents(renderer: RendererPtr, texture: TexturePtr): void =
  var go = true
  var pixels: PixBuf[CANVAS_WIDTH * CANVAS_HEIGHT]
  for i in pixels.low..pixels.high:
    pixels[i] = uint32(0xff000000 or i*218)
  while go:
    var event: Event
    case event.kind:
      of QuitEvent:
        go = false
      else: discard
    updateTexture(texture, nil, addr pixels, CANVAS_WIDTH * PIXEL_SIZE)
    clear(renderer)
    copy(renderer, texture, nil, nil)
    present(renderer)

proc main*(): void =
  var version: SDL_Version
  getVersion(version)
  info "Linked SDL version: ", version
  info "starting SDL"
  if not init(INIT_EVERYTHING).toBool:
    fatal "init failed"
    return
  info "init suceeded"
  let window: WindowPtr = createWindow(
    "test",
    SDL_WINDOWPOS_CENTERED,
    SDL_WINDOWPOS_CENTERED,
    CANVAS_WIDTH,
    CANVAS_HEIGHT,
    0)
  info "window created"
  let renderer = createRenderer(window, -1, 0)
  info "renderer created"
  let texture = createTexture(
    renderer,
    SDL_PIXELFORMAT_ARGB8888,
    SDL_TEXTUREACCESS_STREAMING,
    CANVAS_WIDTH,
    CANVAS_HEIGHT)
  handleEvents(renderer, texture)
  destroyTexture texture
  destroyRenderer renderer
  destroyWindow window
  info "window destroyed"
  sdl2.quit()
