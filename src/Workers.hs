module Workers where

import Control.Monad
import Control.Concurrent
import qualified Data.Map as Map

import Scheduler.Queue
import Workers.Queue
import Queue
import Stage

------------------------------------------------------------------------

startWorkers :: Int -> SchedulerQueue -> Stages -> IO WorkerQueues
startWorkers cpus schedulerQueue stageQueues = do
  workerQueues <- forM [0..cpus - 1] $ \cpu -> do
    let workerId = WorkerId cpu
    workerQueue <- newQueue
    _pid <- forkOn cpu $ do
      putStrLn ("Starting worker " ++ show (getWorkerId workerId))
      writeQueue schedulerQueue (WorkerReady workerId)
      workerLoop workerId workerQueue
    return (workerId, workerQueue)
  return (Map.fromList workerQueues)
  where
    workerLoop workerId workerQueue = do
      msg <- readQueue workerQueue
      case msg of
        DoTask task -> do
          putStrLn  $ "worker " ++ show (getWorkerId workerId) ++ ": got " ++ show task
          let stage = stageQueues Map.! taskStageId task
          case stage of
            Stage _stageId stageInQueue stageOutQueue stageFunction -> do
              go stageInQueue stageOutQueue stageFunction (taskSize task)
              workerLoop workerId workerQueue
      where
        go _q _q' _f 0 = writeQueue schedulerQueue (WorkerReady workerId)
        go  q  q'  f n = do
          mx <- readQueue q
          case mx of
            EndOfStream -> do
              writeQueue q  EndOfStream -- For other workers to read.
              writeQueue q' EndOfStream
              writeQueue schedulerQueue (WorkerDone workerId)
              putStrLn ("Shutting down worker " ++ show (getWorkerId workerId))
            Message x   -> do
              y <- f x
              writeQueue q' (Message y)
              go q q' f (n - 1)

