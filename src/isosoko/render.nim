import sdl2
#import logging
import globals
import buffers
import atomics

type SoftRenderer* = object
  currentFrame: int = 0
  renderLock: AtomicFlag
  buffer*: ptr PixBuf[CANVAS_WIDTH * CANVAS_HEIGHT]

var sren: ptr SoftRenderer = createShared SoftRenderer

proc setSren*(to: SoftRenderer): void =
  sren[] = to

proc cleanupGlobals*(): void =
  deallocShared sren

proc createFrameEvent*(): ptr Event =
  let ev: UserEventPtr = create UserEventObj
  ev[].kind = UserEvent
  return cast [ptr Event](ev)

proc drawScene*(): void =
  #debug "drawing frame ", sren[].currentFrame
  if sren[].renderLock.testAndSet(): return
  var pixels = sren[].buffer
  for i in pixels[].low..pixels[].high:
    pixels[][i] = uint32(0xff000000 or sren[].currentFrame*16 + i)
  inc sren[].currentFrame
  sren[].renderLock.clear()
