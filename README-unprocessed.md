# Elastically scalable parallel pipelines

Implicit parallelism via pipelining is a topic that interests me. The idea is
that we can get parallelism for free by splitting our task up in stages and
arranging them in a pipeline, similarly to how manufacturing and CPUs do.

The basic idea is that each stage runs independenly (one CPU/core) and the stages are connected via queues: ...

sharding = more than one cpu/core per stage

I've written about this topic before https://stevana.github.io/pipelined_state_machines.html 
https://stevana.github.io/parallel_stream_processing_with_zero-copy_fan-out_and_sharding.html

In this post I'd like to discuss the following question: what's the best way to
allocate CPUs/cores among the stages? For example, if we only have two
CPUs/cores, but three stages, then it doesn't make any sense to allocate one of
them to the last stage until at least some items has been processed at the
second stage.

I've also written about elastically scaling a single stage up and down
[before](https://stevana.github.io/elastically_scalable_thread_pools.html), but
here we'll take a more global approach.

## Inspiration

* Dataflow languages
* Martin Thompson
* SEDA
* Database engines, e.g. Umbra's morsels?

## Big picture

<img src="https://raw.githubusercontent.com/stevana/scheduled-pipelines/main/images/system-context.png">

<img src="https://raw.githubusercontent.com/stevana/scheduled-pipelines/main/images/container-pipeline.png">


## Prototype implementation

## Benchmarks

* One green thread per stage
* Against single-thread
* N green threads per stage, where N = # of CPUs/cores
* Other libraries?

## Future work

1. scale sharding of disruptors up and down?
1. [visualise](https://stevana.github.io/visualising_datastructures_over_time_using_svg.html)
  the pipelines and how threads are scheduled over time
