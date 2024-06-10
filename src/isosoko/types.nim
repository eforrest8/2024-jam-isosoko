type
  PixBuf*[S: static int] = array[S, uint32]
  SwappableBuffer*[S: static int] = tuple[front, back: PixBuf[S]]
  State* = tuple[]

template swap*(buffer: var SwappableBuffer): void =
  swap(buffer.back, buffer.front)