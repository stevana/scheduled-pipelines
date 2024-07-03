module Workers.Queue where

import Data.Map (Map)

import Queue
import Stage (StageId)

------------------------------------------------------------------------

type WorkerQueue = Queue WorkerMessage

type WorkerQueues = Map WorkerId WorkerQueue

newtype WorkerId = WorkerId { getWorkerId :: Int }
  deriving (Show, Eq, Ord)

data WorkerMessage = DoTask Task

data Task = Task
  { taskStageId :: StageId
  , taskSize    :: Int
  }
  deriving Show


