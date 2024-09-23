There are many ways in which this can be extended, here's a few in no
particular order:

1. Can we find other places where this algorithm pops up? The problem seems
   related to mathematical optimisation, but I haven't been able to find an
   exact match;
2. Can we have scoring algorithms that optimise for latency (prefer working on
   sink queues / preallocate workers on queues that will likely be non-empty)
   vs throughput (avoid switching / dynamically increase batch sizes);
3. The prototype uses simple concurrent queues, what would be more interesting
   is to scale the
   [sharding](https://stevana.github.io/parallel_stream_processing_with_zero-copy_fan-out_and_sharding.html#disruptor-pipeline-deployment)
   of LMAX Disruptors up and down as we allocate/deallocate workers between
   them, that way we could retain determinism of the order in which items are
   processed;
4. It would also be useful to
   [visualise](https://stevana.github.io/visualising_datastructures_over_time_using_svg.html)
   the pipelines and how threads are scheduled over time, for sanity checking and debugging;
5. Finally, anything performance related would benefit from benchmarking on a
   good set of examples. A few things worth trying:
    * Against single-thread, trying to avoid
      [this](http://www.frankmcsherry.org/graph/scalability/cost/2015/01/15/COST.html);
    * One core per stage
    * N green threads per stage, where N = # of CPUs/cores? Are there better
      ways to offload the rebalancing to the runtime?
    * Other libraries?
