import os
import tables

type Task* = object
  shouldStop: bool = false
  interval: int
  action: proc()

var activeTasks = initTable[Task, Thread[void]]()

proc wrap[T](fn: proc(t: T), arg: T): proc =
  return proc () = fn(arg)

proc taskbody(t: Task) =
  if t.shouldStop: return
  t.action()
  sleep t.interval

proc schedule*[T](interval: int, body: proc(self: var T), arg: T): Task =
  var task = Task(interval: interval, action: wrap(body: body, arg: arg))
  let thread: Thread[void]
  createThread(
    thread,
    wrap(taskbody, task))
  discard activeTasks.hasKeyOrPut(task, thread)
  return task

proc stop*(task: var Task) =
  task.shouldStop = true

proc await*(task: var Task) =
  let thread = activeTasks.getOrDefault(task)
  task.shouldStop = true
  joinThread thread
  activeTasks.del(task)

# EXPERIMENTAL ZONE BELOW
type
  StoppableLoop = object
    #
