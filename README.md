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

![first benchmark](https://github.com/brianwu02/WuExchange/blob/master/imgs/performance.png)





### Trader GenServer Process

### MatchingEngine GenServer Process

### TransactionScribe GenServer Process

### OrderScribe GenServer Process


## Additional Resources
1. [here](https://www.connamara.com/exchanges/) a description of Exchanges and Matching Engines
https://martinfowler.com/articles/lmax.html

