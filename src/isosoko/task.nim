import std/tasks
import std/cpuinfo
import winim/lean

type
  ThreadStatus = enum
    uninitialized, idle, active
  WorkerCommandKind = enum
    TaskCommand, ShutdownCommand
  WorkerCommand = object
    case kind: WorkerCommandKind
    of TaskCommand: task: Task
    of ShutdownCommand: shutdown: void
  ThreadCommunicationChannel = (Channel[Task], var ref ThreadStatus)
  ThreadPool = object
    threads: array[countProcessors(), Thread[ThreadCommunicationChannel]]
    channel: array[countProcessors(), ThreadCommunicationChannel]
  ThreadHandle = object
    id: int
    pool: ref ThreadPool

proc initThreadPool(): ThreadPool =
  result = ThreadPool()
  for i in result.threads.low..result.threads.high:
    let channel = (new Channel[Task].open(), uninitialized)
    result.status[i] = channel
    createThread(result.threads[i], createWorker(), channel)
  return result

const GLOBAL_THREADPOOL: ThreadPool = initThreadPool()

proc schedule(self: ThreadPool = GLOBAL_THREADPOOL, task: Task, interval: uint): ThreadHandle =
  discard

proc submit(self: ThreadPool = GLOBAL_THREADPOOL, task: Task): ThreadHandle =
  let id = selectWorker(self)
  self.channel[0].send(task)
  return ThreadHandle(id, self)

proc createWorker(channel: ThreadCommunicationChannel): void =
  let (cmd, status) = channel
  status = idle
  while true:
    let msg = cmd.recv()
    case msg:
    of TaskCommand:
      status = active
      msg.task.invoke()
      status = idle
    of ShutdownCommand:
      status = uninitialized
      return

