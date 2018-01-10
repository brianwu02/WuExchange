# WuExchange

WuExchange is a securities trading platform written in Elixir for educational purposes.

A Trader places buy limit / sell limit orders against listed securities. When an order is placed by a Trader,
the Matching Engine attempts to match an incoming order with an existing order that satisfies our matching criteria.
When a matching order is found, it is then executed and later transcribed by our TransactionScribe.
If the order is not matched, it is placed in a queue using a [Price-Time Priority Algorithm](https://www.cmegroup.com/confluence/display/EPICSANDBOX/Matching+Algorithms)

The Trader, MatchingEngine and TransactionScribe exist within their own execution runtime using
GenServer provided the Erlang OTP Framework. Seperating the runtime for each of these processes
provides us with isolation guaruntees that allow us to grow functionality irrespective to
dependencies one system may have on another, not to mention the extremely desired behavior: system
failures will not bring down non-dependant parts of the application. tl;dr: a trader process failing
shouldn't crash the Matching Engine and vice versa. we can think of our system as a collection of small,
independent threads of logic that communicate with other processes through an agreed upon interface.


The Trader, MatchingEngine, and TransactionScribe exist within the boundaries of our wu_exchange_backend
umbrella application and is responsible for all business logic powering the interactions between Traders
and the Exchange.

The wu_exchange_web umbrella app is a stripped Phoenix Web application 

## Some thoughts on design goals

An exchange platform that behaves deterministically and favors: correctness, developer agility, and stability.
Performance: throughput, latency, execution speed are not overlooked, but viewed
as secondary. Let's build something simple / correct system and then optimize for performance.


linearizability ...


## Examples

#### Scenario 1

```
```

## Performance Characteristics
The Erlang Virtual Machine runs as one OS process per available core. Code execution is done using erlang
light-weight processes inside the erlang virtual machine. 
we can think of the erlang virtual machine as the operating system and an erlang process as an operating system process.

### Some Early Benchamarking

##### Hardware / Software Specs:

Elixir: 1.5.0
Erlang: 20.2
Operating system: macOS
Available memory: 16 GB
CPU Information: Intel(R) Core(TM) i7-4850HQ CPU @ 2.30GHz
Number of Available Cores: 8

![first benchmark](https://github.com/brianwu02/WuExchange/blob/master/imgs/performance.png)

Benchmarking is done using [benchee](https://github.com/PragTob/benchee), a very simple function benchmarking tool written
in elxiir.

At a quick glance, we can see that it takes 5 microseconds for an insert operation. In these benchmarks,
all initialization (creating process, data structures) are done prior to executing the benchmarks. Should
be a fairly good indicator of how long an operation should take under optimal conditions. These are synthetic
benchmarks and would not reflect real-world performance and only serve to give us a baseline of what to expect.

##### Inserting a Buy / Sell Limit Order

An insert operation, which is a O(1) map lookup, and O(1) [queue insert](http://erlang.org/doc/man/queue.html) should 
take same amount of time regardless of queue size (number of queued and unmatched orders).
This is supported by our benchmarks which show a single insert taking 5μs, and 1000 inserts at roughly 9200μs.
The high deviation could be attributed to multiple factors:
First, we are running this benchmark on my laptop which means there exists process
contention between the erlang VM and other operating system processes (chrome, messengers, etc).
Second: the erlang VM garbage collector. the erlang GC is not a stop-the-world GC, but a stop-the-process GC
meaning each time garbage collection criterion is met, the process must stop and allow for garbage collection
to occur. [Here's](http://theerlangelist.com/article/reducing_maximum_latency) a blog post by Sasa Juric detailing how to optimize for latency in long lived processes.
Each light-weight process runs it's own garbage collector and garbage collection occurs when the stack meets the heap (they grow towards each other)

This means that as we continue to insert orders in to our queue, heap space increases and GC criterion will be met causing the process to GC.
I'm not 100% positive on this, but this could explain why we see run-time spikes amongst multiple runs -- the GC process kicking in and re-sizing the heap.

[insert_1000](https://github.com/brianwu02/WuExchange/blob/master/imgs/insert_1000_orders.png)

We could test this hypothesis by warming up the process or by increasing the default heap size of a process and re-running the benchmarks.
Another thing we could do is side-step the GC issues entirely by implementing (another thing to do!) our data store in [ETS](http://erlang.org/doc/man/ets.html) (Erlang Term Storage).
ETS data is stored in a seperate process which means our process won't need to as many references causing individual GC times to
be greatly decreased. see examples of this [here](http://theerlangelist.com/article/reducing_maximum_latency)


### Trader GenServer Process

### MatchingEngine GenServer Process

### TransactionScribe GenServer Process

### OrderScribe GenServer Process


## Additional Resources
1. [here](https://www.connamara.com/exchanges/) a description of Exchanges and Matching Engines
2. [Read this for much better explanation of erlang gc](https://hamidreza-s.github.io/erlang%20garbage%20collection%20memory%20layout%20soft%20realtime/2015/08/24/erlang-garbage-collection-details-and-why-it-matters.html)
3. [single threaded matching example by martin folower](https://martinfowler.com/articles/lmax.html)
4. [Order Book Imp in Python](https://github.com/kmanley/orderbook/blob/master/orderbook.py)
5. [Order Book Imp in Go](https://github.com/kmanley/gorderbook)

