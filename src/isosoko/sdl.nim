import sdl2
import sdlcanvas
import globals
import logging
import render2
import malebolgia
import options

type
  UserEventType = enum
    FrameEvent, PhysicsEvent

const THREADS_ENABLED = true

let userEventKind = registerEvents(1)

proc createUserEvent(code: UserEventType): ptr Event =
  let ev: UserEventPtr = create UserEventObj
  ev[].kind = EventType(userEventKind)
  ev[].code = int32(code)
  return cast [ptr Event](ev)

proc handleEvents(canvas: ptr SDLCanvas): void =
  var go = true
  #m.spawn renderLoop()
  while go:
    var event: Event
    if waitEvent(event):
      #debug event
      case event.kind:
        of QuitEvent:
          go = false
        of UserEvent:
          let uev: UserEventObj = cast[UserEventPtr](addr event)[]
          case uev.code:
            of int32(FrameEvent):
              updateTexture(canvas[].texture, nil, canvas[].buffer, CANVAS_WIDTH * PIXEL_SIZE)
              clear(canvas[].renderer)
              copy(canvas[].renderer, canvas[].texture, nil, nil)
              present(canvas.renderer)
            of int32(PhysicsEvent):
              inc tick[]
              if tick[] > 999: tick[] = 0
            else:
              debug "Received invalid UserEvent! data: ", uev
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
    var m = createMaster()
    while active[]:
      delay(100)
      when THREADS_ENABLED:
        m.awaitAll:
          drawScene(some(getHandle(m)))
      else:
        drawScene()
      discard pushEvent(createUserEvent(FrameEvent))
  var tickThread: Thread[ptr uint32]
  let tickRate = create uint32
  tickRate[] = 50
  proc scheduleTick(rate: ptr uint32): void {.thread, nimcall.}=
    while rate[] > 0:
      delay(rate[])
      discard pushEvent(createUserEvent(PhysicsEvent))
  createThread(drawThread, scheduleDraw, drawActive)
  #createThread(tickThread, scheduleTick, tickRate)
  handleEvents canvas # runs until quit
  destroyCanvas canvas
  cleanupGlobals()
  drawActive[] = false
  joinThread drawThread
  dealloc drawActive
  #joinThread tickThread
  dealloc tickRate
  deallocShared tick
  info "canvas destroyed"
  sdl2.quit()
