#[
  A bucket is an unordered container which automatically
  assigns and reclaims indices when items are added or removed.
]#
import std/setutils
import sillysets
import tables
import options

type
  Bucket*[T: ref] = object
    available: set[uint16] = fullSet uint16
    elements: var array[uint16.high, T]

proc incl*[T](self: Bucket[T], e: T): uint16 =
  let nextIndex = self.available.highestElement().get()
  self.elements.add(nextIndex, e)
  self.available.excl nextIndex
  return nextIndex

proc pop*(self: Bucket, index: uint16): Bucket.T =
  result = self.elements.pop index
  self.available.incl index
  return result

proc del*(self: Bucket, index: uint16): void =
  self.elements.del index
  self.available.incl index

proc `[]`*(self: Bucket, index: uint16): Bucket.T =
  return self.elements[index]

iterator items*(self: Bucket): Bucket.T =
  for e in items self.elements:
    yield e

iterator pairs*(self: Bucket): Bucket.T =
  for e in pairs self.elements:
    yield e

when isMainModule:
  var b = Bucket[ref int]()
  let val: ref int = new(int)
  doAssert b.incl(val) == b.available.low