{-# LANGUAGE ExistentialQuantification #-}

module Stage where

import Control.Monad
import Data.IORef
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Typeable
import Data.Word

import Queue

------------------------------------------------------------------------

type StageId = String

type Stages = Map StageId SomeStage

data SomeStage = forall a b. (Typeable a, Typeable b) =>
  SomeStage (Stage a b)

data Stage a b = Stage
  { _stageId           :: StageId
  , _stageInQueue      :: StageQueue a
  , _stageOutQueue     :: StageQueue b
  , _stageFunction     :: a -> IO b
  , _stageServiceTimes :: IORef [Word64]
  }

type StageQueue a = Queue (Envelop a)

data Envelop a = Message a | EndOfStream

-- start snippet QueueStats
data QueueStats = QueueStats
  { queueLength       :: Int
  , serviceTimesPicos :: [Word64]
  }
  deriving Show
-- end snippet

------------------------------------------------------------------------

makeStages :: [SomeStage] -> Stages
makeStages stages
  = Map.fromList
  $ map (\(i, stage) ->
      case stage of
        SomeStage stage_ ->
          let
            -- Prefix stage names with their index, so that the `Stages`
            -- `Map`` preserves the insertion order.
            stageId' = show i ++ "-" ++ _stageId stage_
          in
            (stageId', SomeStage (stage_ { _stageId = stageId' })))
      (zip [(0 :: Int)..] stages)

newStage_ :: StageId -> Queue (Envelop a) -> (a -> IO b) -> IO (Stage a b)
newStage_ stageId inQueue stageFunction = do
  outQueue <- newQueue
  serviceTimes <- newIORef []
  return (Stage stageId inQueue outQueue stageFunction serviceTimes)

newStage :: StageId -> Stage a b -> (b -> IO c) -> IO (Stage b c)
newStage stageId stage stageFunction =
  newStage_ stageId (_stageOutQueue stage) stageFunction

lengthStageInQueue :: Stage a b -> IO Int
lengthStageInQueue (Stage _ inq _ _ _) = lengthQueue inq

queueStatsStages :: Stages -> IO (Map StageId QueueStats)
queueStatsStages stages = do
  qstats <- forM (Map.toList stages) $ \(stageId, SomeStage stage) -> do
    len <- lengthStageInQueue stage
    serviceTimes <- readIORef (_stageServiceTimes stage)
    return (stageId, QueueStats len serviceTimes)
  return (Map.fromList qstats)

newSource :: [a] -> IO (Stage a a)
newSource xs0 = do
  q <- newQueue
  mapM_ (writeQueue q . Message) xs0
  writeQueue q EndOfStream
  newStage_ "Source" q return

newSink :: Stage a b -> (b -> IO ()) -> IO (Stage b ())
newSink stage sink = newStage "Sink" stage sink
