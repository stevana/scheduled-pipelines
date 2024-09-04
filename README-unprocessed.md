# Elastically scalable parallel pipelines

*Work in progress, please don't share, but do feel free to get involved!*

This post is about how to schedule workers across a pipeline of queues in order
to minimise total processing time, and an unexpected connection between this
kind of scheduling and Thomas Jefferson.

## Background and motiviation

Implicit parallelism via pipelining is a topic that interests me. The idea is
that we can get parallelism for free by splitting our task up in stages and
arranging them in a pipeline, similarly to how manufacturing and CPUs do.

The way it works is that each stage runs independenly (one CPU/core) and the
stages are connected via queues, so when the first CPU/core is done with
the first stage of the first item, it passes it on to the second stage while
continuing to work at the first stage of the second item. As the queues between
the stages saturate we get parallelism while retaining determinism (the outputs
arrive in the same order as the inputs).

Here's a picture of a bottle factory manufacturing pipeline:

<img src="https://raw.githubusercontent.com/stevana/scheduled-pipelines/main/images/bottling-factory.png">

Each stage is connected by conveyor belts (queues) and runs in parallel with
the other, e.g. after as the first bottle has been filled, the second can be
filled while at the same time the first bottle is being capped.

If a stage is slow, then an input queue to the stage can be partitioned or
sharded by adding another worker to that stage sending every other input to the
newly added worker, thereby effectively nearly doubling the throughput.

In this post I'd like to discuss the following question: what's the best way to
allocate CPUs/cores among the stages? For example, if we only have two
CPUs/cores, but three stages, then it doesn't make any sense to allocate one of
them to the last stage until at least some items has been processed at the
second stage.

First I'd like to develop a library to test out these concepts, but longer term
I'd like to make a programming language which uses these concepts to try see if
we can make something that scales well as more CPUs/cores are available.

## Inspiration and prior work

Pipelining parallelism isn't something I've come up with myself. 

While there are examples of pipelining in manufactoring that pre-date Henry
Ford, it seems that's when it took off and become a common place. Wikipedia
says:

> "The assembly line, driven by conveyor belts, reduced production time for a
> Model T to just 93 minutes by dividing the process into 45 steps. Producing
> cars quicker than paint of the day could dry, it had an immense influence on
> the world."

CPUs are another example where pipelining is used, with the intent of speeding
up the processing of instructions. A pipeline might look like: fetch the
instruction, fetch the operands, do the instruction, and finally write the
results.

Give this tremendous success in both manufactoring and hardware one could
expect that perhaps it's worth doing in software as well?

For reasons not entirely clear to me, it hasn't seem to have taken off yet, but
there are proponents of this idea.

Jim Gray talked about software pipeline parallelism and partitioning in his
Turing award [interview](https://www.youtube.com/watch?v=U3eo49nVxcA&t=1949s).

[Dataflow languages](https://en.wikipedia.org/wiki/Dataflow_programming) in
general and Paul Morrison’s [flow-based
programming](https://jpaulm.github.io/fbp/index.html) in particular exploit
this idea.

The [LMAX Disruptor](https://lmax-exchange.github.io/disruptor/disruptor.html)
pattern is also based on pipelining parallelism and supports, what Jim calls,
partition parallelism. One of the sources that the Disruptor paper mentions is
[SEDA](https://people.eecs.berkeley.edu/~brewer/papers/SEDA-sosp.pdf).

More recently, as I was digging into more of Jim's
[work](https://jimgray.azurewebsites.net/papers/CacmParallelDB.pdf), I
discovered that database engines also implement something akin to pipeline
parallelism. One of the most advanced examples of this is Umbra's
[morsels](https://db.in.tum.de/~leis/papers/morsels.pdf).

These are the examples of software pipeline parallelism that inspired me to
start thinking about it.

However it wasn't until I read Martin Thompson, one of the people behind the LMAX
Disruptor, say the following:

> "If there’s one thing I’d say to the Erlang folks, it’s you got the stuff
> right from a high-level, but you need to invest in your messaging
> infrastructure so it’s super fast, super efficient and obeys all the right
> properties to let this stuff work really well."

together with Joe Armstrong's anecdote of an unmodified Erlang program only
running 33 times faster on a 64 core machine, rather than 64 times faster as
per the Ericsson higher-up’s expectations, that I started thinking about how a
programming language can improve upon the already excellent work that Erlang is
doing in this space.

I've written about this topic before https://stevana.github.io/pipelined_state_machines.html 
https://stevana.github.io/parallel_stream_processing_with_zero-copy_fan-out_and_sharding.html

I've also written about elastically scaling a single stage up and down
[before](https://stevana.github.io/elastically_scalable_thread_pools.html), but
here we'll take a more global approach.

## Big picture

The system consists of three parts: the pipeline, the workers and the scheduler:

<img src="https://raw.githubusercontent.com/stevana/scheduled-pipelines/main/images/system-context.png">

The scheduler monitors the pipeline, looking at how long the input queues for
each stage is and what the average service time per input of that stage is. By
doing so it calculate where to schedule the available workers.

XXX: the caclulation

The workers, typically one per available CPU/core, process a batch of inputs at
the stage the scheduler instructs them to and then report back to the
scheduler, and so the process repeats until the end of the stream of inputs.

If we zoom in on the pipelne, we see that it consists of a source, N stages and
a sink:

<img src="https://raw.githubusercontent.com/stevana/scheduled-pipelines/main/images/container-pipeline.png">

The source can be a file, network socket, a user provided lists of items, etc,
from which the inputs to the queue of the first stage are created. The inputs
can be length-prefixed raw bytes, or newline-separated bytes, etc.

Similarly the sink can also be a file, or standard out, or a socket.

In between the source and the sink is where the interesting processing happens
in stages.

* Schedulling typically assigns work to queues, but here we assign workers to queues?

## Prototype implementation

From the above picture, I hope that it's clear that most of the code is
plumbing (connecting the components). 

The most interesting aspect is: when a worker is done, how does the scheduler
figure out what it shall tell it to do next?

``` {.haskell include=src/Config.hs snippet=Config .numberLines}
```

``` {.haskell include=src/Config.hs snippet=initConfig .numberLines}
```

``` {.haskell include=src/Config.hs snippet=allocateWorkers .numberLines}
```

``` {.haskell include=src/Config.hs snippet=possibleConfigs .numberLines}
```

``` {.haskell include=src/Config.hs snippet=scores .numberLines}
```

``` {.haskell include=src/Config.hs snippet=joinMapsWith .numberLines}
```

``` {.haskell include=src/Config.hs snippet=allocatesDoneStages .numberLines}
```

```haskell
>>> allocateWorkers 2 
                    (M.fromList [ ("A", QueueStats 3 [])
                                , ("B", QueueStats 0 [])]) 
                    S.empty
Just (Config (fromList [("A",2),("B",0)]))
```

```haskell
>>> allocateWorkers 2 
                    (M.fromList [ ("A", QueueStats 1 [1,1])
                                , ("B", QueueStats 2 [])]) 
                    S.empty
Just (Config (fromList [("A",1),("B",1)]))
```

```haskell
>>> allocateWorkers 2 
                    (M.fromList [ ("A", QueueStats 0 [1,1,1])
                                , ("B", QueueStats 2 [1])]) 
                    (S.fromList ["A"])
Just (Config (fromList [("A",0),("B",2)]))
```

```haskell
>>> allocateWorkers 2 
                    (M.fromList [ ("A", QueueStats 0 [1,1,1])
                                , ("B", QueueStats 0 [1,1,1])]) 
                    (S.fromList ["A", "B"])
Nothing
```

## Unexpected connection to Thomas Jefferson

* [Jefferson method](https://en.wikipedia.org/wiki/D%27Hondt_method)

## Future work

1. scoring algorithms that optimise for latency (prefer working on sink queues
   / preallocate workers on queues that will likely be non-empty) vs throughput
   (avoid switching / dynamically increase batch sizes)?
1. good set of examples
1. benchmarking
  * One green thread per stage
  * Against single-thread
  * N green threads per stage, where N = # of CPUs/cores
  * Other libraries?
1. scale sharding of disruptors up and down?
1. [visualise](https://stevana.github.io/visualising_datastructures_over_time_using_svg.html)
  the pipelines and how threads are scheduled over time
