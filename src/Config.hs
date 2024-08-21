module Config where

import Control.Exception (assert)
import Data.List
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Ord
import Data.Set (Set)
import qualified Data.Set as Set

import Stage (StageId)

------------------------------------------------------------------------

-- start snippet Config
newtype Config = Config (Map StageId NumOfWorkers)
  deriving Show

type NumOfWorkers = Int
-- end snippet

------------------------------------------------------------------------

initConfig :: [StageId] -> Config
initConfig stageIds =
  Config (Map.fromList (zip stageIds (replicate (length stageIds) 0)))

-- https://stackoverflow.com/questions/22939260/every-way-to-organize-n-objects-in-m-list-slots
possibleConfigs :: Int -> [StageId] -> [Config]
possibleConfigs cpus stages = map (Config . Map.fromList . zip stages) $ filter ((== cpus) . sum)
  [ foldl' (\ih i -> update i succ ih) (replicate (length stages) 0) slot
  | choice <- combinations [0.. (cpus + length stages - 1)] cpus
  , let slot = [ c - i | (i, c) <- zip [0.. ] choice ]
  ]
  where
    combinations :: [a] -> Int -> [[a]]
    combinations xs n = filter ((== n) . length) (subsequences xs)

    update :: Int -> (a -> a) -> [a] -> [a]
    update i f = go [] i
      where
        go acc _ []       = reverse acc
        go acc 0 (x : xs) = reverse acc ++ f x : xs
        go acc n (x : xs) = go (x : acc) (n - 1) xs

changeStage :: StageId -> Config -> StageId
changeStage old (Config diff)
  | diff Map.! old >= 0 = old
  | otherwise           = go 0 (Map.elems diff)
  where
    stageIds = Map.keys diff

    go _new [] = error ("shouldChange: impossible, a diff always has the sum of 0, diff = " ++ show diff)
    go  new (i : is) | i > 0     = stageIds !! new
                     | otherwise = go (new + 1) is

diffConfig :: Config -> Config -> Config
diffConfig (Config old) (Config new) =
  Config (joinMapsWith diffInt old new)

-- https://www.haskellforall.com/2014/12/a-very-general-api-for-relational-joins.html
joinMapsWith :: Ord k => (a -> b -> c) -> Map k a -> Map k b -> Map k c
joinMapsWith f m1 m2 = assert (Map.keys m1 == Map.keys m2) $
  Map.fromList
    [ (k, f x (m2 Map.! k))
    | (k, x) <- Map.toList m1
    ]

diffInt :: Int -> Int -> Int
diffInt old new = new - old

data QueueStats = QueueStats
  { queueLength       :: Int
  , serviceTimesPicos :: [Integer]
  }

avgServiceTime :: QueueStats -> Integer
avgServiceTime qs
  | len == 0  = 1
  | otherwise = sum (serviceTimesPicos qs) `div` len
  where
    len = genericLength (serviceTimesPicos qs)

-- https://en.wikipedia.org/wiki/D%27Hondt_method
-- https://en.wikipedia.org/wiki/Sainte-Lagu%C3%AB_method
score :: QueueStats -> Int -> Double
score qs workers =
  (fromIntegral (queueLength qs) * fromIntegral (avgServiceTime qs))
  /
  (fromIntegral workers + 1)

scores :: Map StageId Int -> Config -> Map StageId Double
scores lens (Config cfg) =
  joinMapsWith (\len -> score (QueueStats len [])) lens cfg

allocateWorkers :: Int -> Map StageId Int -> Set StageId -> Maybe Config
allocateWorkers cpus lens done = case result of
  [] -> Nothing
  (cfg, _score) : _ -> Just cfg
  where
    result = sortBy (comparing snd)
               [ (cfg, sum (Map.elems (scores lens cfg)))
               | cfg <- possibleConfigs cpus (Map.keys lens)
               , not (allocatesDoneStages cfg done)
               ]

allocatesDoneStages :: Config -> Set StageId -> Bool
allocatesDoneStages (Config cfg) done =
  any (\(stageId, numWorkers) -> stageId `Set.member` done && numWorkers > 0)
      (Map.toList cfg)
