import std/monotimes
import times
import atomics
import tables
import algorithm

type
  TaskReportKind* = enum
    start, finish
  TaskReport* = object
    kind*: TaskReportKind
    id*: int
    time*: MonoTime
  TaskTimer* = object
    reports*: seq[TaskReport]
    nextid*: Atomic[int]

proc initReport*(): ptr TaskTimer =
  let p = createShared(TaskTimer)
  p[] = TaskTimer()
  return p

proc writeReport*(timer: ptr TaskTimer): void =
  let output = open("perfData.txt", fmWrite, 2048)
  var timetable: Table[int, tuple[s, e: MonoTime]]
  for r in timer[].reports:
    case r.kind:
      of start: timetable.mgetOrPut(r.id, (s: MonoTime(), e: MonoTime())).s = r.time
      of finish: timetable.mgetOrPut(r.id, (s: MonoTime(), e: MonoTime())).e = r.time
  var firstStart = MonoTime.high
  for s, _ in timetable.values:
    firstStart = if s < firstStart: s else: firstStart
  var lastEnd = MonoTime.low
  for _, e in timetable.values:
    lastEnd = if e > lastEnd: e else: lastEnd
  var durations: OrderedTable[int, Duration]
  for k, v in timetable.pairs:
    discard durations.hasKeyOrPut(k, v.e - v.s)
  var lowTime = Duration.high
  for d in durations.values:
    lowTime = if d < lowTime: d else: lowTime
  var highTime = Duration.low
  var highPixel = -1
  for k, d in durations.pairs:
    if d > highTime:
      highTime = d
      highPixel = k
  var sum = Duration()
  for d in durations.values:
    sum += d
  let mean = sum div durations.len
  var dSeq: seq[Duration]
  for d in durations.values:
    dSeq.add(d)
  sort(dSeq)
  let median = dSeq[dseq.len div 2]
  output.writeLine "total render time: ", lastEnd - firstStart
  output.writeLine "sum of pixel times: ", sum
  output.writeLine "highest pixel time: ", highTime
  output.writeLine "  highest pixel's id': ", highPixel
  output.writeLine "lowest pixel time: ", lowTime
  output.writeLine "mean pixel time: ", mean
  output.writeLine "median pixel time: ", median
  output.flushFile()
  output.close()
