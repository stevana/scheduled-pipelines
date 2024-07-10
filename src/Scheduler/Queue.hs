module Scheduler.Queue where

import Queue

import Workers.Queue (WorkerId)
import Stage (StageId)

------------------------------------------------------------------------

type SchedulerQueue = Queue SchedulerMessage

data SchedulerMessage 
  = WorkerReady WorkerId
  | StageDone StageId
