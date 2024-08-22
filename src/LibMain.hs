module LibMain where

import Control.Concurrent

import Queue
import Scheduler
import Stage
import Workers

------------------------------------------------------------------------

main :: IO ()
main = do

  let inputSize = 3
  let batchSize = 1
  let cpus = 2 -- <- getNumCapabilities

  putStrLn "Deploying pipeline"
  s1 <- newSource (replicate inputSize ())
  s2 <- newStage "A" s1 (const (threadDelay 10000))
  s3 <- newStage "B" s2 (const (threadDelay 20000))
  s4 <- newSink s3 print

  schedulerQueue <- newQueue

  let stages = makeStages
                [SomeStage s1, SomeStage s2, SomeStage s3, SomeStage s4]

  putStrLn "Starting workers"
  workerQueues <- startWorkers cpus schedulerQueue stages

  putStrLn "Starting scheduler"
  startScheduler cpus batchSize schedulerQueue stages workerQueues
