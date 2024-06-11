import sdlcanvas

type SoftRenderer* = object
  currentFrame: int = 0
  canvas*: SDLCanvas

proc drawScene*(self: var SoftRenderer): void =
  var pixels = self.canvas.buffer.back
  for i in pixels.low..pixels.high:
    pixels[i] = uint32(0xff000000 or self.currentFrame + i*16)
  inc self.currentFrame
