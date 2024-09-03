# Elastically scalable parallel pipelines

*Work in progress, please don't share, but do feel free to get
involved!*

This post is about how to schedule workers across a pipeline of queues
in order to minimise total processing time, and an unexpected connection
between this kind of scheduling and Thomas Jefferson.

## Background and motiviation

Implicit parallelism via pipelining is a topic that interests me. The
idea is that we can get parallelism for free by splitting our task up in
stages and arranging them in a pipeline, similarly to how manufacturing
and CPUs do.

The way it works is that each stage runs independenly (one CPU/core) and
the stages are connected via queues, so when the first CPU/core is done
with the first stage of the first item, it passes it on to the second
stage while continuing to work at the first stage of the second item. As
the queues between the stages saturate we get parallelism while
retaining determinism (the outputs arrive in the same order as the
inputs).

Here's a picture of a bottle factory manufacturing pipeline:

<img src="https://raw.githubusercontent.com/stevana/scheduled-pipelines/main/images/bottling-factory.png">

Each stage is connected by conveyor belts (queues) and runs in parallel
with the other, e.g. after as the first bottle has been filled, the
second can be filled while at the same time the first bottle is being
capped.

If a stage is slow, then an input queue to the stage can be partitioned
or sharded by adding another worker to that stage sending every other
input to the newly added worker, thereby effectively nearly doubling the
throughput.

In this post I'd like to discuss the following question: what's the best
way to allocate CPUs/cores among the stages? For example, if we only
have two CPUs/cores, but three stages, then it doesn't make any sense to
allocate one of them to the last stage until at least some items has
been processed at the second stage.

First I'd like to develop a library to test out these concepts, but
longer term I'd like to make a programming language which uses these
concepts to try see if we can make something that scales well as more
CPUs/cores are available.

## Inspiration and prior work

Pipelining parallelism isn't something I've come up with myself.

While there are examples of pipelining in manufactoring that pre-date
Henry Ford, it seems that's when it took off and become a common place.
Wikipedia says:

> "The assembly line, driven by conveyor belts, reduced production time
> for a Model T to just 93 minutes by dividing the process into 45
> steps. Producing cars quicker than paint of the day could dry, it had
> an immense influence on the world."

CPUs are another example where pipelining is used, with the intent of
speeding up the processing of instructions. A pipeline might look like:
fetch the instruction, fetch the operands, do the instruction, and
finally write the results.

Give this tremendous success in both manufactoring and hardware one
could expect that perhaps it's worth doing in software as well?

For reasons not entirely clear to me, it hasn't seem to have taken off
yet, but there are proponents of this idea.

Jim Gray talked about software pipeline parallelism and partitioning in
his Turing award
[interview](https://www.youtube.com/watch?v=U3eo49nVxcA&t=1949s).

[Dataflow languages](https://en.wikipedia.org/wiki/Dataflow_programming)
in general and Paul Morrison’s [flow-based
programming](https://jpaulm.github.io/fbp/index.html) in particular
exploit this idea.

The [LMAX
Disruptor](https://lmax-exchange.github.io/disruptor/disruptor.html)
pattern is also based on pipelining parallelism and supports, what Jim
calls, partition parallelism. One of the sources that the Disruptor
paper mentions is
[SEDA](https://people.eecs.berkeley.edu/~brewer/papers/SEDA-sosp.pdf).

More recently, as I was digging into more of Jim's
[work](https://jimgray.azurewebsites.net/papers/CacmParallelDB.pdf), I
discovered that database engines also implement something akin to
pipeline parallelism. One of the most advanced examples of this is
Umbra's [morsels](https://db.in.tum.de/~leis/papers/morsels.pdf).

These are the examples of software pipeline parallelism that inspired me
to start thinking about it.

However it wasn't until I read Martin Thompson, one of the people behind
the LMAX Disruptor, say the following:

> "If there’s one thing I’d say to the Erlang folks, it’s you got the
> stuff right from a high-level, but you need to invest in your
> messaging infrastructure so it’s super fast, super efficient and obeys
> all the right properties to let this stuff work really well."

together with Joe Armstrong's anecdote of an unmodified Erlang program
only running 33 times faster on a 64 core machine, rather than 64 times
faster as per the Ericsson higher-up’s expectations, that I started
thinking about how a programming language can improve upon the already
excellent work that Erlang is doing in this space.

I've written about this topic before
<https://stevana.github.io/pipelined_state_machines.html>
<https://stevana.github.io/parallel_stream_processing_with_zero-copy_fan-out_and_sharding.html>

I've also written about elastically scaling a single stage up and down
[before](https://stevana.github.io/elastically_scalable_thread_pools.html),
but here we'll take a more global approach.

## Big picture

The system consists of three parts: the pipeline, the workers and the
scheduler:

<img src="https://raw.githubusercontent.com/stevana/scheduled-pipelines/main/images/system-context.png">

<img src="https://raw.githubusercontent.com/stevana/scheduled-pipelines/main/images/container-pipeline.png">

- Schedulling typically assigns work to queues, but here we assign
  workers to queues?

## Prototype implementation

From the above picture, I hope that it's clear that most of the code is
plumbing (connecting the components).

The most interesting aspect is: when a worker is done, how does the
scheduler figure out what it shall tell it to do next?

``` haskell
newtype Config = Config (Map StageId NumOfWorkers)
  deriving Show

type NumOfWorkers = Int
```

``` haskell
initConfig :: [StageId] -> Config
initConfig stageIds =
  Config (Map.fromList (zip stageIds (replicate (length stageIds) 0)))
```

``` haskell
allocateWorkers :: Int -> Map StageId QueueStats -> Set StageId -> Maybe Config
allocateWorkers cpus qstats done = case result of
  []                -> Nothing
  (cfg, _score) : _ -> Just cfg
  where
    result = sortBy (comparing snd)
               [ (cfg, sum (Map.elems (scores qstats cfg)))
               | cfg <- possibleConfigs cpus (Map.keys qstats)
               , not (allocatesDoneStages cfg done)
               ]
```

``` haskell
possibleConfigs :: Int -> [StageId] -> [Config]
possibleConfigs cpus stages = map (Config . Map.fromList . zip stages) $ filter ((== cpus) . sum)
  [ foldl' (\ih i -> update i succ ih) (replicate (length stages) 0) slot
  | choice <- combinations [0.. (cpus + length stages - 1)] cpus
  , let slot = [ c - i | (i, c) <- zip [0.. ] choice ]
  ]
  where
    combinations :: [a] -> Int -> [[a]]
    combinations xs n = filter ((== n) . length) (subsequences xs)

    -- update i f xs = xs[i] := f (xs[i])
    update :: Int -> (a -> a) -> [a] -> [a]
    update i f = go [] i
      where
        go acc _ []       = reverse acc
        go acc 0 (x : xs) = reverse acc ++ f x : xs
        go acc n (x : xs) = go (x : acc) (n - 1) xs
```

``` haskell
scores :: Map StageId QueueStats -> Config -> Map StageId Double
scores qss (Config cfg) = joinMapsWith score qss cfg
  where
    score :: QueueStats -> Int -> Double
    score qs workers =
      (fromIntegral (queueLength qs) * fromIntegral avgServiceTimePicos)
      /
      (fromIntegral workers + 1)
      where
        avgServiceTimePicos :: Word64
        avgServiceTimePicos
          | len == 0  = 1 -- XXX: What's the right value here?
          | otherwise = sum (serviceTimesPicos qs) `div` len
          where
            len :: Word64
            len = genericLength (serviceTimesPicos qs)
```

``` haskell
joinMapsWith :: Ord k => (a -> b -> c) -> Map k a -> Map k b -> Map k c
joinMapsWith f m1 m2 = assert (Map.keys m1 == Map.keys m2) $
  Map.fromList
    [ (k, f x (m2 Map.! k))
    | (k, x) <- Map.toList m1
    ]
```

``` haskell
allocatesDoneStages :: Config -> Set StageId -> Bool
allocatesDoneStages (Config cfg) done =
  any (\(stageId, numWorkers) -> stageId `Set.member` done && numWorkers > 0)
      (Map.toList cfg)
```

``` haskell
>>> allocateWorkers 2 (M.fromList [("A", QueueStats 3 []), ("B", QueueStats 0 [])]) S.empty
Just (Config (fromList [("A",2),("B",0)]))
```

``` haskell
>>> allocateWorkers 2 (M.fromList [("A", QueueStats 1 [1,1]), ("B", QueueStats 2 [])]) S.empty
Just (Config (fromList [("A",1),("B",1)]))
```

``` haskell
>>> allocateWorkers 2 (M.fromList [("A", QueueStats 0 [1,1,1]), ("B", QueueStats 2 [1])]) (S.fromList ["A"])
Just (Config (fromList [("A",0),("B",2)]))
```

``` haskell
>>> allocateWorkers 2 (M.fromList [("A", QueueStats 0 [1,1,1]), ("B", QueueStats 0 [1,1,1])]) (S.fromList ["A", "B"])
Nothing
```

## Unexpected connection to Thomas Jefferson

- [Jefferson method](https://en.wikipedia.org/wiki/D%27Hondt_method)

## Future work

1.  scoring algorithms that optimise for latency (prefer working on sink
    queues / preallocate workers on queues that will likely be
    non-empty) vs throughput (avoid switching / dynamically increase
    batch sizes)?
2.  good set of examples
3.  benchmarking

- One green thread per stage
- Against single-thread
- N green threads per stage, where N = \# of CPUs/cores
- Other libraries?

1.  scale sharding of disruptors up and down?
2.  [visualise](https://stevana.github.io/visualising_datastructures_over_time_using_svg.html)
    the pipelines and how threads are scheduled over time
