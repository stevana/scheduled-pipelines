module Queue where

import Control.Concurrent.STM
import Numeric.Natural

------------------------------------------------------------------------

mAX_QUEUE_LENGTH :: Natural
mAX_QUEUE_LENGTH = 128

------------------------------------------------------------------------

newtype Queue a = Queue (TBQueue a)

newQueue :: IO (Queue a)
newQueue = Queue <$> newTBQueueIO mAX_QUEUE_LENGTH

readQueue :: Queue a -> IO a
readQueue (Queue q) = atomically (readTBQueue q)

writeQueue :: Queue a -> a -> IO ()
writeQueue (Queue q) x = atomically (writeTBQueue q x)

lengthQueue :: Queue a -> IO Int
lengthQueue (Queue q) = fromIntegral <$> atomically (lengthTBQueue q)
