module Scheduler where

import Data.Map (Map)
import qualified Data.Map as Map

import Config
import Queue
import Stage
import Workers.Queue
import Scheduler.Queue

------------------------------------------------------------------------

data SchedulerState = SchedulerState
  { runningTasks :: Map WorkerId Task
  , lastConfig   :: Config
  , workerCount  :: Int
  }

------------------------------------------------------------------------

initSchedulerState :: Int -> [StageId] -> SchedulerState
initSchedulerState cpus stageIds = SchedulerState 
  { runningTasks = Map.empty 
  , lastConfig   = initConfig stageIds
  , workerCount  = cpus
  }

startScheduler :: Int -> SchedulerQueue -> Stages -> WorkerQueues -> IO ()
startScheduler cpus schedulerQueue stages workerQueues = do
  go (initSchedulerState cpus stageIds)
  where
    stageIds = Map.keys stages

    go state = do
      msg <- readQueue schedulerQueue
      case msg of
        WorkerDone _workerId -> 
          let workerCount' = workerCount state - 1  in
          if workerCount' == 0
          then putStrLn "Scheduler done"
          else go state { workerCount = workerCount' }
        WorkerReady workerId -> do
          -- XXX: collect stats about service time
          let mOldTask = runningTasks state Map.!? workerId
          queueStats <- lengthStages stages
          putStr "Queue lengths: "
          print queueStats
          let newConfig = allocateWorkers cpus queueStats
          let diff = diffConfig (lastConfig state) newConfig
          putStr "Config diff: "
          print diff
          let mOldStageId = taskStageId <$> mOldTask
          let newStageId = changeStage mOldStageId diff
          case mOldTask of
            Nothing -> putStrLn $ "worker " ++ show (getWorkerId workerId) ++ 
              ": started working on stage " ++ show newStageId
            Just oldTask | newStageId == taskStageId oldTask -> 
              putStrLn $ "worker " ++ show (getWorkerId workerId) ++ 
              ": kept working on stage " ++ show (taskStageId oldTask) 
                         | otherwise -> 
              putStrLn $ "worker " ++ show (getWorkerId workerId) ++ ": changed from stage " ++ 
                show (taskStageId oldTask) ++ 
                " to stage " ++ show newStageId
          let size = 1 -- XXX: size?
          let newTask = Task newStageId size
          let state' = state 
                         { runningTasks = 
                             Map.insert workerId newTask (runningTasks state) 
                         , lastConfig = newConfig
                         }
          putStrLn $ "scheduler, sending " ++ show newTask ++ " to worker " ++ show (getWorkerId workerId)
          writeQueue (workerQueues Map.! workerId) (DoTask newTask)
          go state'

