module LibMain where

import qualified Data.Map as Map
import Control.Concurrent

import Queue
import Stage
import Scheduler
import Workers

------------------------------------------------------------------------

main :: IO ()
main = do

  putStrLn "Deploying pipeline"
  q1 <- newSource [0..2 :: Int]
  (s1, q2) <- newStage 0 q1 (const (threadDelay 10000))
  (s2, q3) <- newStage 1 q2 (const (threadDelay 20000))
  newSink q3 print

  schedulerQueue <- newQueue 

  let stages = Map.fromList (zip [0..] [s1, s2])

  let cpus = 2 -- <- getNumCapabilities

  putStrLn "Starting workers"
  workerQueues <- startWorkers cpus schedulerQueue stages

  putStrLn "Starting scheduler"
  startScheduler cpus schedulerQueue stages workerQueues
