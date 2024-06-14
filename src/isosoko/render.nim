#import logging
import globals
import buffers
import atomics
import bitops

type SoftRenderer* = object
  currentFrame: int = 0
  renderLock: AtomicFlag
  buffer*: ptr PixBuf[CANVAS_WIDTH * CANVAS_HEIGHT]

var sren: ptr SoftRenderer = createShared SoftRenderer

proc setSren*(to: SoftRenderer): void =
  sren[] = to

proc cleanupGlobals*(): void =
  deallocShared sren

proc drawScene*(): void =
  #debug "drawing frame ", sren[].currentFrame
  if sren[].renderLock.testAndSet(): return
  var pixels = sren[].buffer
  for i in pixels[].low..pixels[].high:
    let x = i mod CANVAS_WIDTH / CANVAS_WIDTH
    let y = i / CANVAS_WIDTH / CANVAS_HEIGHT
    pixels[][i] = uint32(0xff000000 or
      #int(rotateLeftBits(uint(sren[].currentFrame) + uint((1-x)*255), 24)) or
      int(rotateLeftBits(uint(sren[].currentFrame) + uint(x*255), 16)) or
      int(rotateLeftBits(uint(sren[].currentFrame) + uint(y*255), 8)) or
      int(rotateLeftBits(uint(sren[].currentFrame) + uint(((1-y)+(1-x))/2*255), 0))
    )
  inc sren[].currentFrame
  if sren[].currentFrame > 255: sren[].currentFrame = 0
  sren[].renderLock.clear()
