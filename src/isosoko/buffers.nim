import logging

type
  PixBuf*[S: static int] = array[S, uint32]
  SwappableBuffer*[S: static int] = tuple[front, back: PixBuf[S]]

template swap*(buffer: var SwappableBuffer): void =
  debug "swapping ", buffer.back[0], ", ", buffer.front[0]
  swap(buffer.back, buffer.front)