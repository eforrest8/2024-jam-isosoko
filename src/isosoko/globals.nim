const CANVAS_WIDTH* = 320
const CANVAS_HEIGHT* = 240
const PIXEL_SIZE* = sizeof(uint32)

let tick*: ptr int = createShared int
