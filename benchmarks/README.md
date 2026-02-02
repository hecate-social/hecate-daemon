# Performance Testing Suite

This directory contains performance tests for the macula-hecate CQRS stack.

## Quick Start

```bash
# Run all performance tests
./run_perf_tests.sh

# Run specific scenario
./run_perf_tests.sh command_throughput
```

## Test Scenarios

### 1. Command Throughput Test

Tests high-volume command dispatch throughput.

**Configuration:**
- Number of commands: 1000
- Pattern: Sequential command dispatch
- Measures: Command latency, throughput

**Acceptance Criteria:**
- Throughput: > 500 commands/sec
- P95 latency: < 50ms

### 2. Concurrent Read/Write Test

Tests concurrent operations with multiple workers.

**Configuration:**
- Number of workers: 100
- Operations per worker: 10 (write + read)
- Pattern: Each worker writes then reads
- Measures: Combined read/write latency

**Acceptance Criteria:**
- No deadlocks or crashes
- Read latency: < 10ms (P95)

### 3. Large Stream Test

Tests performance with large event streams.

**Configuration:**
- Number of events: 10,000
- Pattern: Multiple events to same stream
- Measures: Latency degradation over time

**Acceptance Criteria:**
- Latency remains stable (P99 < 100ms)
- No memory leaks
- Linear scaling

### 4. Projection Lag Test

Measures time between event storage and read model update.

**Configuration:**
- Number of samples: 100
- Pattern: Write event, poll for projection
- Measures: Time from event dispatch to queryable

**Acceptance Criteria:**
- Projection lag: < 100ms (P95)
- No missed projections

## Metrics Collected

For each scenario, the following metrics are collected:

- **Total operations**: Number of operations performed
- **Duration**: Wall-clock time for scenario
- **Throughput**: Operations per second
- **Latency percentiles**: P50, P95, P99 in milliseconds
- **Errors**: Number of failed operations
- **Memory delta**: Memory used during test (MB)

## Running Tests

### Prerequisites

Ensure all applications are started:

```erlang
% Start all command services
application:ensure_all_started(manage_capabilities).
application:ensure_all_started(manage_social).
application:ensure_all_started(manage_subscriptions).
application:ensure_all_started(manage_identities).
application:ensure_all_started(manage_ucan).

% Start all query services
application:ensure_all_started(query_capabilities).
application:ensure_all_started(query_social).
application:ensure_all_started(query_subscriptions).
application:ensure_all_started(query_identities).
application:ensure_all_started(query_ucan).
```

### Via Shell Script

```bash
cd test/performance
./run_perf_tests.sh
```

### Via Erlang Shell

```erlang
% Compile and load
c(perf_test_runner).

% Run all tests
perf_test_runner:run_all().

% Run specific test
perf_test_runner:run_scenario(command_throughput).
perf_test_runner:run_scenario(concurrent_readwrite).
perf_test_runner:run_scenario(large_stream).
perf_test_runner:run_scenario(projection_lag).
```

### Via Rebar3

```bash
# Run as part of test suite
rebar3 eunit --module=perf_test_runner
```

## Interpreting Results

### Example Output

```
=== Running scenario: command_throughput ===
Testing command throughput with 1000 commands...

Results:
  Total operations: 1000
  Duration: 1523 ms
  Throughput: 656.60 ops/sec
  Latency P50: 1.234 ms
  Latency P95: 2.456 ms
  Latency P99: 4.567 ms
  Errors: 0
  Memory delta: 12.34 MB
```

### What to Look For

**Good Performance:**
- Throughput > 500 ops/sec
- P95 latency < 50ms for commands
- P95 latency < 10ms for queries
- Projection lag < 100ms
- Zero errors
- Linear memory scaling

**Performance Issues:**
- Throughput declining over time (memory leak, resource exhaustion)
- High error rates (contention, timeouts)
- Large latency spikes (GC pauses, blocking operations)
- Excessive memory usage (aggregate not releasing, projection backlog)

## Troubleshooting

### High Latency

**Possible Causes:**
- ReckonDB disk I/O bottleneck
- SQLite write contention
- Network latency to mesh
- Erlang scheduler saturation

**Debug Steps:**
1. Check ReckonDB logs for slow writes
2. Monitor SQLite journal mode (WAL vs DELETE)
3. Profile with `fprof` or `eprof`
4. Check scheduler utilization: `erlang:statistics(scheduler_wall_time)`

### Low Throughput

**Possible Causes:**
- Sequential bottleneck (not parallelizing)
- Synchronous operations blocking
- Gen_server bottleneck
- Aggregate locking

**Debug Steps:**
1. Check for synchronous gen_server calls in hot path
2. Verify projections are async
3. Monitor gen_server message queue lengths
4. Profile with `recon:proc_count(message_queue_len, 10)`

### Projection Lag

**Possible Causes:**
- Subscriber not keeping up
- SQLite write latency
- Projection logic too heavy
- Event batching not enabled

**Debug Steps:**
1. Check subscriber message queue: `process_info(Pid, message_queue_len)`
2. Enable SQLite WAL mode
3. Profile projection functions
4. Monitor ReckonDB event publish rate

## Continuous Integration

Performance tests can be integrated into CI:

```yaml
# .github/workflows/performance.yml
- name: Run performance tests
  run: |
    cd test/performance
    ./run_perf_tests.sh

- name: Check thresholds
  run: |
    # Parse results and fail if thresholds not met
    ./check_perf_thresholds.sh results.json
```

## Benchmarking Different Configurations

### SQLite Journal Modes

Test with different SQLite configurations:

```erlang
% In query service store init
sqlite3:exec(Db, "PRAGMA journal_mode=WAL").  % Write-Ahead Logging
sqlite3:exec(Db, "PRAGMA journal_mode=DELETE").  % Default
sqlite3:exec(Db, "PRAGMA synchronous=NORMAL").  % Less fsync
```

### ReckonDB Batch Size

Test with different event batch sizes in `reckon_evoq_adapter`:

```erlang
reckon_evoq_adapter:subscribe(
    StoreId,
    EventType,
    Subscriber,
    #{batch_size => 10}  % Adjust batch size
).
```

### Concurrency Levels

Adjust the number of workers in concurrent tests:

```erlang
perf_test_runner:concurrent_readwrite_test(50).   % 50 workers
perf_test_runner:concurrent_readwrite_test(200).  % 200 workers
```

## Performance Baseline

As of 2026-02-01 (initial implementation):

| Scenario | Throughput | P50 | P95 | P99 |
|----------|------------|-----|-----|-----|
| Command Throughput | TBD | TBD | TBD | TBD |
| Concurrent R/W | TBD | TBD | TBD | TBD |
| Large Stream | TBD | TBD | TBD | TBD |
| Projection Lag | N/A | TBD | TBD | TBD |

**Update this table after running initial tests.**

## Future Improvements

- [ ] Add memory profiling with `recon`
- [ ] Add disk I/O monitoring
- [ ] Add network bandwidth tests
- [ ] Test with multiple concurrent aggregates
- [ ] Add chaos testing (kill processes mid-operation)
- [ ] Add long-running soak tests (hours/days)
- [ ] Benchmark against EventStoreDB for comparison
- [ ] Add visualization of results (graphs over time)
