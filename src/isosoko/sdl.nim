import sdl2
import sdlcanvas
import globals
import logging
import render
import os
import malebolgia

let FrameEvent: uint32 = registerEvents(1)

addHandler newConsoleLogger()

proc handleEvents(canvas: ptr SDLCanvas): void =
  var m = createMaster()
  var go = true
  while go:
    var event: Event
    if waitEvent(event):
      #debug event
      case event.kind:
        of QuitEvent:
          go = false
        of UserEvent:
          m.spawn drawScene()
          updateTexture(canvas[].texture, nil, canvas[].buffer, CANVAS_WIDTH * PIXEL_SIZE)
          clear(canvas[].renderer)
          copy(canvas[].renderer, canvas[].texture, nil, nil)
          present(canvas.renderer)
        else: discard

proc start*(): void =
  var version: SDL_Version
  getVersion(version)
  info "Linked SDL version: ", version
  if not init(INIT_EVERYTHING).toBool:
    fatal "SDL init failed"
    return
  info "SDL init suceeded"
  var canvas = initCanvas()
  setSren SoftRenderer(buffer: canvas[].buffer)
  var drawThread: Thread[ptr bool]
  let drawActive = create bool
  drawActive[] = true
  proc scheduleDraw(active: ptr bool): void {.thread, nimcall.}=
    while active[]:
      sleep(33)
      discard pushEvent(createFrameEvent())
  createThread(drawThread, scheduleDraw, drawActive)
  handleEvents canvas # runs until quit
  destroyCanvas canvas
  cleanupGlobals()
  drawActive[] = false
  joinThread drawThread
  dealloc drawActive
  info "canvas destroyed"
  sdl2.quit()
