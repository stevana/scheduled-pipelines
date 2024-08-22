module Scheduler where

import Control.Concurrent
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Set (Set)
import qualified Data.Set as Set

import Config
import Queue
import Scheduler.Queue
import Stage
import Workers.Queue

------------------------------------------------------------------------

data SchedulerState = SchedulerState
  { runningTasks :: Map WorkerId Task
  , lastConfig   :: Config
  , doneStages   :: Set StageId
  }

------------------------------------------------------------------------

initSchedulerState :: [StageId] -> SchedulerState
initSchedulerState stageIds = SchedulerState
  { runningTasks = Map.empty
  , lastConfig   = initConfig stageIds
  , doneStages   = Set.empty
  }

type BatchSize = Int

startScheduler :: Int -> BatchSize -> SchedulerQueue -> Stages -> WorkerQueues -> IO ()
startScheduler cpus size schedulerQueue stages workerQueues = do
  go (initSchedulerState stageIds)
  where
    stageIds = Map.keys stages

    go state = do
      msg <- readQueue schedulerQueue
      case msg of
        StageDone stageId -> do
          let doneStages' = Set.insert stageId (doneStages state)
          print doneStages'
          if Set.fromList stageIds == doneStages'
          then putStrLn "Shutting down scheduler in 1ms..." >> threadDelay 1000
          else go state { doneStages = doneStages' }
        WorkerReady workerId -> do
          -- XXX: collect stats about service time
          let mOldTask = runningTasks state Map.!? workerId
          queueStats <- queueStatsStages stages
          putStr "Queue stats: "
          print queueStats
          let mNewConfig = allocateWorkers cpus queueStats (doneStages state)
          putStrLn $ "scheduler, allocateWorkers: " ++ show mNewConfig
          case mNewConfig of
            Nothing -> do
              writeQueue (workerQueues Map.! workerId) Shutdown
              go state
            Just newConfig -> do
              let diff = diffConfig (lastConfig state) newConfig
              putStr "Config diff: "
              print diff
              let mOldStageId = taskStageId <$> mOldTask
              let newStageId = case mOldStageId of
                                Nothing         -> stageIds !! 0
                                Just oldStageId -> changeStage oldStageId diff
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
              let newTask = Task newStageId size
              let state' = state
                             { runningTasks =
                                 Map.insert workerId newTask (runningTasks state)
                             , lastConfig = newConfig
                             }
              putStrLn $ "scheduler, sending " ++ show newTask ++ " to worker " ++ show (getWorkerId workerId)
              writeQueue (workerQueues Map.! workerId) (DoTask newTask)
              go state'

