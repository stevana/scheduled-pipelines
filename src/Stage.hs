{-# LANGUAGE ExistentialQuantification #-}

module Stage where

import Control.Monad
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Typeable

import Queue

------------------------------------------------------------------------

type StageId = String

type Stages = Map StageId SomeStage

data SomeStage = forall a b. (Typeable a, Typeable b) => 
  SomeStage (Stage a b)

data Stage a b = Stage
  { _stageId       :: StageId
  , _stageInQueue  :: StageQueue a
  , _stageOutQueue :: StageQueue b
  , _stageFunction :: a -> IO b
  }

type StageQueue a = Queue (Envelop a)

data Envelop a = Message a | EndOfStream

------------------------------------------------------------------------

makeStages :: [SomeStage] -> Stages
makeStages stages 
  = Map.fromList 
  $ map (\(i, stage) -> 
      case stage of
        SomeStage (Stage stageId _ _ _) -> (show i ++ "-" ++ stageId, stage)) 
      (zip [(0 :: Int)..] stages)

newStage_ :: StageId -> Queue (Envelop a) -> (a -> IO b) -> IO (Stage a b)
newStage_ stageId inQueue stageFunction = do
  outQueue <- newQueue
  return (Stage stageId inQueue outQueue stageFunction)

newStage :: StageId -> Stage a b -> (b -> IO c) -> IO (Stage b c)
newStage stageId stage stageFunction = 
  newStage_ stageId (_stageOutQueue stage) stageFunction

lengthStageInQueue :: Stage a b -> IO Int
lengthStageInQueue (Stage _ inq _ _ ) = lengthQueue inq

lengthStages :: Stages -> IO (Map StageId Int)
lengthStages stages = do
  lens <- forM (Map.toList stages) $ \(stageId, SomeStage stage) -> do
    len <- lengthStageInQueue stage
    return (stageId, len)
  return (Map.fromList lens)

newSource :: [a] -> IO (Stage a a)
newSource xs0 = do
  q <- newQueue
  mapM_ (writeQueue q . Message) xs0
  writeQueue q EndOfStream
  newStage_ "Source" q return

newSink :: Stage a b -> (b -> IO ()) -> IO (Stage b ())
newSink stage sink = newStage "Sink" stage sink
