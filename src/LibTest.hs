module LibTest where

import Control.Concurrent
import Control.Monad

import Queue
import Scheduler
import Stage
import Workers

------------------------------------------------------------------------
--
unit_oneStageOneWorker :: IO Bool
unit_oneStageOneWorker = do

  let inputSize = 3
  let batchSize = 1
  let cpus = 1

  putStrLn "Deploying pipeline"
  let input = replicate inputSize ()
  s1 <- newSource (replicate inputSize ())
  s2 <- newStage "A" s1 (const (threadDelay 10000))
  outQueue <- newQueue
  s3 <- newSink s2 (writeQueue outQueue)

  schedulerQueue <- newQueue

  let stages = makeStages [SomeStage s1, SomeStage s2, SomeStage s3]

  putStrLn "Starting workers"
  workerQueues <- startWorkers cpus schedulerQueue stages

  putStrLn "Starting scheduler"
  startScheduler cpus batchSize schedulerQueue stages workerQueues

  output <- replicateM inputSize (readQueue outQueue)
  return (output == input)

unit_oneStageTwoWorkers :: IO Bool
unit_oneStageTwoWorkers = do

  let inputSize = 3
  let batchSize = 1
  let cpus = 2

  putStrLn "Deploying pipeline"
  let input = replicate inputSize ()
  s1 <- newSource (replicate inputSize ())
  s2 <- newStage "A" s1 (const (threadDelay 10000))
  outQueue <- newQueue
  s3 <- newSink s2 (writeQueue outQueue)

  schedulerQueue <- newQueue

  let stages = makeStages [SomeStage s1, SomeStage s2, SomeStage s3]

  putStrLn "Starting workers"
  workerQueues <- startWorkers cpus schedulerQueue stages

  putStrLn "Starting scheduler"
  startScheduler cpus batchSize schedulerQueue stages workerQueues

  output <- replicateM inputSize (readQueue outQueue)
  return (output == input)

unit_twoStagesTwoWorkers :: IO Bool
unit_twoStagesTwoWorkers = do

  let inputSize = 30
  let batchSize = 5
  let cpus = 2

  putStrLn "Deploying pipeline"
  let input = replicate inputSize ()
  s1 <- newSource (replicate inputSize ())
  s2 <- newStage "A" s1 (const (threadDelay 20000))
  s3 <- newStage "B" s2 (const (threadDelay 10000))
  outQueue <- newQueue
  s4 <- newSink s3 (writeQueue outQueue)

  schedulerQueue <- newQueue

  let stages = makeStages
                [SomeStage s1, SomeStage s2, SomeStage s3, SomeStage s4]

  putStrLn "Starting workers"
  workerQueues <- startWorkers cpus schedulerQueue stages

  putStrLn "Starting scheduler"
  startScheduler cpus batchSize schedulerQueue stages workerQueues

  output <- replicateM inputSize (readQueue outQueue)
  return (output == input)
