import sdl2
import sdlcanvas
import globals
import logging
import task
import render

proc handleEvents(canvas: SDLCanvas): void =
  var go = true
  while go:
    var event: Event
    while waitEvent(event):
      case event.kind:
        of QuitEvent:
          go = false
        else: discard
    updateTexture(canvas.texture, nil, addr canvas.buffer.front, CANVAS_WIDTH * PIXEL_SIZE)
    clear(canvas.renderer)
    copy(canvas.renderer, canvas.texture, nil, nil)
    present(canvas.renderer)

proc start*(): void =
  var version: SDL_Version
  getVersion(version)
  info "Linked SDL version: ", version
  if not init(INIT_EVERYTHING).toBool:
    fatal "SDL init failed"
    return
  info "SDL init suceeded"
  var canvas = initCanvas()
  var sren = SoftRenderer(canvas: canvas)
  var drawTask = schedule(33, drawScene, sren)
  handleEvents canvas # runs until quit
  await drawTask
  destroyCanvas canvas
  info "canvas destroyed"
  sdl2.quit()
