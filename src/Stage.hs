{-# LANGUAGE ExistentialQuantification #-}

module Stage where

import Control.Concurrent
import Control.Monad
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Typeable

import Queue

------------------------------------------------------------------------

type StageId = Int

type Stages = Map StageId Stage

data Stage = forall a b. (Typeable a, Typeable b) => Stage
  { _stageId       :: StageId
  , _stageInQueue  :: StageQueue a
  , _stageOutQueue :: StageQueue b
  , _stageFunction :: a -> IO b
  }

type StageQueue a = Queue (Envelop a)

data Envelop a = Message a | EndOfStream

------------------------------------------------------------------------

newStage :: (Typeable a, Typeable b)
         => StageId -> StageQueue a -> (a -> IO b) -> IO (Stage, StageQueue b)
newStage stageId queueIn stageFunction = do
  queueOut <- newQueue
  return (Stage stageId queueIn queueOut stageFunction, queueOut)

lengthStageInQueue :: Stage -> IO Int
lengthStageInQueue (Stage _ inq _ _ ) = lengthQueue inq

lengthStages :: Stages -> IO (Map StageId Int)
lengthStages stages = do
  lens <- forM (Map.toList stages) $ \(stageId, stage) -> do
    len <- lengthStageInQueue stage
    return (stageId, len)
  return (Map.fromList lens)

newSource :: [a] -> IO (StageQueue a)
newSource xs0 = do
  q <- newQueue
  _pid <- forkIO (go q xs0)
  return q
  where
    go q []       = do
      putStrLn "Shutting down source"
      writeQueue q EndOfStream
    go q (x : xs) = do
      writeQueue q (Message x)
      threadDelay 100000
      go q xs

newSink :: StageQueue a -> (a -> IO ()) -> IO ()
newSink q sink = do
  _pid <- forkIO go
  return ()
  where
    go = do
      mx <- readQueue q
      case mx of
        EndOfStream -> putStrLn "Shutting down sink"
        Message x   -> do
          sink x
          threadDelay 100000
          go
