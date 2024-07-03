module Scheduler.Queue where

import Queue

import Workers.Queue (WorkerId)

------------------------------------------------------------------------

type SchedulerQueue = Queue SchedulerMessage

data SchedulerMessage 
  = WorkerReady WorkerId
  | WorkerDone WorkerId
