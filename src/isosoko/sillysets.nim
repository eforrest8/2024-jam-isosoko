#[
  very silly code from this stackoverflow answer
  https://stackoverflow.com/questions/74673080/pop-for-built-in-sets
  crucially this depends on implementation details of the set type
  so this will break severely if that ever changes

  the proper way to do this is a for loop, but this is so much funnier
]#

import std/[bitops,options]
import nimsimd/[avx,avx2]

template highestSingleImpl[T](s:set[T]) =
  type SetT = (
    when sizeof(s)==1: uint8
    elif sizeof(s)==2: uint16
    elif sizeof(s)==4: uint32
    elif sizeof(s)==8: uint64
  )
  let theBits = cast[SetT](s)
  if theBits == 0:
    none(T)
  else:
    T(sizeof(s)*8 - countLeadingZeroBits(theBits) + T.low.int - 1).some

template highestMultipleImpl[T](s:set[T]) =
  type
    HighT = ptr UncheckedArray[array[32,uint8]]
  when sizeof(s) mod 32 != 0:
    type
      LowT = ptr UncheckedArray[array[sizeof(s) mod 32,uint8]]
    let
      hiBits = cast[HighT](cast[LowT](s.unsafeAddr)[1].addr)
      loBits = cast[LowT](s.unsafeAddr)[0]
  else:
   let hiBits = cast[HighT](s.unsafeAddr)

  var i = sizeof(s) div 32 - 1
  while i >= 0:
    var
      vec = mm256_loadu_si256(hiBits[i].addr)
      nonzero_elem = mm256_cmpeq_epi8(vec, mm256_setzero_si256())
      mask = not mm256_movemask_epi8(nonzero_elem)
    if mask == 0:
      dec i
      continue
    let
      idx = 31 - countLeadingZeroBits(mask)
      highest_nonzero_byte = hiBits[i][idx]
    return T(i*32*8 + idx*8 + 8 - countLeadingZeroBits(highest_nonzero_byte) + T.low.int - 1 + 8 * (sizeof(s) mod 32)).some

  when sizeof(s) mod 32 != 0:
    i = (sizeof(s) mod 32) - 1
    while i >= 0:
      if loBits[i]==0:
        dec i
        continue
      return T(8 - countLeadingZeroBits(loBits[i]) + i*8 + T.low.int - 1).some
  return none(typedesc[T])



proc highestElement*[T](s:set[T]):Option[T]{.raises:[].}=
  when sizeof(s) <= 8:
    highestSingleImpl(s)
  else:
    highestMultipleImpl(s)