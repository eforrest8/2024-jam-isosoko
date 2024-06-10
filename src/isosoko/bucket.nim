#[
  A bucket is an unordered container which automatically
  assigns and reclaims indices when items are added or removed.
]#
import std/setutils
import tables

type
  Bucket*[T] = object
    available: set[int16] = fullSet int16
    elements: Table[int16, T]

proc incl*(self: Bucket, e: ref Bucket.T): int16 =
  let nextIndex = self.available.items[0]
  self.elements.add(nextIndex, e)
  self.available.excl nextIndex
  return nextIndex

proc pop*(self: Bucket, index: int16): Bucket.T =
  result = self.elements.pop index
  self.available.incl index
  return result

proc del*(self: Bucket, index: int16): void =
  self.elements.del index
  self.available.incl index

proc `[]`*(self: Bucket, index: int16): Bucket.T =
  return self.elements[index]

iterator items*(self: Bucket): Bucket.T =
  for e in items self.elements:
    yield e

iterator pairs*(self: Bucket): Bucket.T =
  for e in pairs self.elements:
    yield e
