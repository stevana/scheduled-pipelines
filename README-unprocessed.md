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

<img src="https://raw.githubusercontent.com/stevana/scheduled-pipelines/main/images/bottling-factory.png">

sharding = more than one cpu/core per stage

In this post I'd like to discuss the following question: what's the best way to
allocate CPUs/cores among the stages? For example, if we only have two
CPUs/cores, but three stages, then it doesn't make any sense to allocate one of
them to the last stage until at least some items has been processed at the
second stage.

First I'd like to develop a library to test out these concepts, but longer term
I'd like to make a programming language which uses these concepts to try see if
we can make something that scales well as more CPUs/cores are available.

## Inspiration and prior work

* [Jim Gray](https://www.youtube.com/watch?v=U3eo49nVxcA&t=1949s)

* [Dataflow languages](https://en.wikipedia.org/wiki/Dataflow_programming) and
  Paul Morrison’s [flow-based programming](https://jpaulm.github.io/fbp/index.html)

Martin Thompson, one of the people behind the [LMAX
Disruptor](https://lmax-exchange.github.io/disruptor/disruptor.html), said the
following:

    > "If there’s one thing I’d say to the Erlang folks, it’s you got the stuff
    > right from a high-level, but you need to invest in your messaging
    > infrastructure so it’s super fast, super efficient and obeys all the right
    > properties to let this stuff work really well."

    This quote together with Joe Armstrong's anecdote of an unmodified Erlang
    program only running 33 times faster on a 64 core machine, rather than 64 times
    faster as per the Ericsson higher-up’s expectations, inspired me to think about
    how one can improve upon the already excellent work that Erlang is doing in
    this space.

* [SEDA](https://people.eecs.berkeley.edu/~brewer/papers/SEDA-sosp.pdf)
* Database engines, e.g. Umbra's
  [morsels](https://db.in.tum.de/~leis/papers/morsels.pdf)

I've written about this topic before https://stevana.github.io/pipelined_state_machines.html 
https://stevana.github.io/parallel_stream_processing_with_zero-copy_fan-out_and_sharding.html

I've also written about elastically scaling a single stage up and down
[before](https://stevana.github.io/elastically_scalable_thread_pools.html), but
here we'll take a more global approach.

## Big picture

<img src="https://raw.githubusercontent.com/stevana/scheduled-pipelines/main/images/system-context.png">

<img src="https://raw.githubusercontent.com/stevana/scheduled-pipelines/main/images/container-pipeline.png">

## Prototype implementation

From the above picture, I hope that it's clear that most of the code is
plumbing (connecting the components). 

The most interesting aspect is: when a worker is done, how does the scheduler
figure out what it shall tell it to do next?

``` {.haskell include=src/Config.hs snippet=Config .numberLines}
```

## Unexpected connection to Thomas Jefferson

* [Jefferson method](https://en.wikipedia.org/wiki/D%27Hondt_method)




## Future work

1. good set of examples
1. benchmarking
  * One green thread per stage
  * Against single-thread
  * N green threads per stage, where N = # of CPUs/cores
  * Other libraries?
1. scale sharding of disruptors up and down?
1. [visualise](https://stevana.github.io/visualising_datastructures_over_time_using_svg.html)
  the pipelines and how threads are scheduled over time
