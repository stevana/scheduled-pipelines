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
        Shutdown -> 
          putStrLn  $ "Shutting down worker " ++ show (getWorkerId workerId)
        DoTask task -> do
          putStrLn  $ "worker " ++ show (getWorkerId workerId) ++ ": got " ++ show task
          case stageQueues Map.! taskStageId task of
            SomeStage stage -> do
              processBatch stage (taskSize task)
              workerLoop workerId workerQueue
      where
        processBatch _stage 0 = 
          writeQueue schedulerQueue (WorkerReady workerId)
        processBatch stage@(Stage stageId q q' f) n = do
          mx <- readQueue q
          case mx of
            EndOfStream -> do
              putStrLn  $ "worker " ++ show (getWorkerId workerId) ++ ": done with stage " ++ show stageId
              unGetQueue q  EndOfStream -- For other workers to read.
              writeQueue q' EndOfStream
              writeQueue schedulerQueue (StageDone stageId)
              writeQueue schedulerQueue (WorkerReady workerId)
            Message x   -> do
              y <- f x
              writeQueue q' (Message y)
              processBatch stage (n - 1)

