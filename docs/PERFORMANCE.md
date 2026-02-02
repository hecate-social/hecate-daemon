# Performance Characteristics

This document describes the performance characteristics, known bottlenecks, and optimization strategies for macula-hecate's CQRS architecture.

## Architecture Overview

```
Command → Handler → ReckonDB (event store) → Events
                                                ↓
                          Projections ← Event subscription
                                                ↓
                                        SQLite (read models)
                                                ↓
                                        Query ← REST API
```

## Performance Targets

| Metric | Target | Rationale |
|--------|--------|-----------|
| Command throughput | > 500 ops/sec | Adequate for typical agent workloads |
| Query latency (P95) | < 10ms | Sub-100ms user experience |
| Projection lag (P95) | < 100ms | Near real-time consistency |
| Memory per aggregate | < 10MB | Allow 100+ active aggregates |
| Startup time | < 5 sec | Fast daemon restart |

## Bottlenecks and Optimizations

### 1. ReckonDB Write Performance

**Bottleneck:** Event persistence is disk I/O bound.

**Characteristics:**
- Sequential writes to log-structured storage
- Each command results in 1+ events written
- Fsync on every write (durability guarantee)

**Optimizations:**
```erlang
% Enable batch writes in reckon_db
reckon_db:configure(#{
    batch_size => 100,        % Batch up to 100 events
    batch_timeout_ms => 10    % Flush after 10ms
}).

% Use async dispatch where possible
reckon_evoq_adapter:dispatch_async(Cmd).
```

**Trade-offs:**
- Batching increases throughput but adds latency
- Async dispatch improves responsiveness but complicates error handling

### 2. SQLite Projection Updates

**Bottleneck:** SQLite write contention during high-volume projections.

**Characteristics:**
- One SQLite DB per query service
- Projections run in dedicated gen_server
- Default journal mode: DELETE (synchronous)

**Optimizations:**
```erlang
% Enable WAL mode (Write-Ahead Logging)
sqlite3:exec(Db, "PRAGMA journal_mode=WAL").

% Reduce fsync frequency
sqlite3:exec(Db, "PRAGMA synchronous=NORMAL").

% Use transactions for batch updates
sqlite3:exec(Db, "BEGIN TRANSACTION").
lists:foreach(fun(Event) -> project(Event, Db) end, Events).
sqlite3:exec(Db, "COMMIT").
```

**Trade-offs:**
- WAL mode improves concurrency but uses more disk space
- `synchronous=NORMAL` risks data loss on power failure
- Batch transactions improve throughput but increase projection lag

### 3. Event Subscription Overhead

**Bottleneck:** Polling for new events adds latency.

**Characteristics:**
- Query services poll ReckonDB for new events
- Default poll interval: 100ms
- Each query service has dedicated subscriber

**Optimizations:**
```erlang
% Reduce poll interval (increases CPU usage)
reckon_evoq_adapter:subscribe(
    StoreId,
    EventType,
    Subscriber,
    #{poll_interval_ms => 10}
).

% Use event notifications instead of polling (future)
reckon_db:notify_on_event(StoreId, EventType, Pid).
```

**Trade-offs:**
- Lower poll interval reduces lag but increases CPU/network
- Push notifications eliminate polling but add complexity

### 4. Aggregate Memory Usage

**Bottleneck:** Keeping aggregates in memory consumes RAM.

**Characteristics:**
- Each aggregate loads full event history on first access
- Aggregates cached in-memory for subsequent commands
- No automatic eviction policy

**Optimizations:**
```erlang
% Implement LRU cache for aggregates
evoq_aggregate_cache:configure(#{
    max_size => 100,          % Keep 100 aggregates in memory
    eviction_policy => lru    % Least recently used
}).

% Use snapshots for large aggregates
evoq:snapshot(AggregateId, State, Version).
```

**Trade-offs:**
- Eviction reduces memory but increases latency (reload from events)
- Snapshots reduce replay time but add storage overhead

### 5. Mesh Publishing Overhead

**Bottleneck:** Publishing every event to mesh adds network I/O.

**Characteristics:**
- Each event published to Macula mesh via HTTP/3
- Mesh projections run synchronously in event flow
- No batching or buffering

**Optimizations:**
```erlang
% Make mesh publishing async
spawn(fun() ->
    hecate_mesh_publisher:publish_event(EventType, EventData)
end).

% Batch multiple events before publishing
buffer_events_and_publish_when(100, 1000).  % 100 events or 1 sec
```

**Trade-offs:**
- Async publishing improves command latency but complicates delivery guarantees
- Batching improves network efficiency but delays visibility

## Recommended Configuration

### Development (Fast Iteration)

```erlang
%% config/dev.config
[
    {reckon_db, [
        {batch_size, 1},           % No batching, immediate writes
        {fsync, true}              % Full durability
    ]},
    {query_capabilities, [
        {sqlite_journal_mode, delete},  % Default mode
        {sqlite_synchronous, full}      % Full durability
    ]},
    {hecate_mesh_publisher, [
        {async, false}             % Synchronous for debugging
    ]}
].
```

### Production (High Performance)

```erlang
%% config/prod.config
[
    {reckon_db, [
        {batch_size, 100},         % Batch writes
        {batch_timeout_ms, 10},    % Max 10ms delay
        {fsync, true}              % Keep durability
    ]},
    {query_capabilities, [
        {sqlite_journal_mode, wal},     % WAL for concurrency
        {sqlite_synchronous, normal},   % Reduce fsync
        {batch_projections, true},      % Batch projection updates
        {batch_size, 50}
    ]},
    {hecate_mesh_publisher, [
        {async, true},             % Async publishing
        {buffer_size, 100},        % Buffer events
        {buffer_timeout_ms, 1000}  % Max 1 sec delay
    ]}
].
```

## Monitoring

### Key Metrics to Track

```erlang
%% Command throughput
hecate_metrics:get(commands_per_sec).

%% Query latency
hecate_metrics:histogram(query_latency_ms).

%% Projection lag
hecate_metrics:gauge(projection_lag_ms).

%% Aggregate cache hit rate
hecate_metrics:get(aggregate_cache_hit_rate).

%% ReckonDB write latency
hecate_metrics:histogram(reckondb_write_latency_ms).

%% SQLite write latency
hecate_metrics:histogram(sqlite_write_latency_ms).
```

### Process Monitoring

```erlang
%% Message queue lengths (detect backpressure)
recon:proc_count(message_queue_len, 10).

%% Memory usage by process
recon:proc_count(memory, 10).

%% Scheduler utilization
erlang:statistics(scheduler_wall_time).
```

### Disk I/O Monitoring

```bash
# Monitor ReckonDB write rate
iostat -x 1 | grep sda

# Monitor SQLite write rate
lsof -p <erlang-pid> | grep .db

# Check for fsync bottlenecks
strace -p <erlang-pid> -e fsync
```

## Scaling Strategies

### Vertical Scaling

**When to Scale Up:**
- CPU utilization > 80%
- Scheduler saturation
- Memory pressure

**How to Scale Up:**
- Add more CPU cores (Erlang schedulers scale linearly)
- Add more RAM (cache more aggregates)
- Use faster disk (NVMe for ReckonDB)

### Horizontal Scaling

**Current Limitations:**
- All command services run on single node
- ReckonDB is embedded (not distributed)
- No aggregate sharding

**Future Enhancements:**
- Shard aggregates by ID range
- Run command services on multiple nodes
- Use distributed ReckonDB cluster
- Implement event replication

### Read Scaling

**Query services can be scaled independently:**

```
Command Service (single node)
        ↓
    ReckonDB
        ↓
   Event Stream
     ↙   ↓   ↘
Query1  Query2  Query3  (multiple nodes)
  ↓       ↓       ↓
SQLite1 SQLite2 SQLite3
```

**Benefits:**
- Read replicas reduce query load
- Geographic distribution (low latency)
- Specialized read models (search, analytics)

## Performance Testing

See `test/performance/README.md` for detailed performance testing guide.

**Quick Start:**

```bash
cd test/performance
./run_perf_tests.sh
```

## Known Issues and Limitations

### 1. No Backpressure

**Issue:** High command rate can overwhelm projections.

**Impact:** Projection lag increases, memory usage grows.

**Workaround:** Rate limit at API layer.

**Future Fix:** Implement backpressure in subscription layer.

### 2. No Event Batching in Mesh Projections

**Issue:** Each event published individually to mesh.

**Impact:** High network overhead, poor throughput.

**Workaround:** Reduce mesh publishing (only critical events).

**Future Fix:** Batch events before publishing.

### 3. Aggregate Cache Never Evicts

**Issue:** Aggregates stay in memory forever.

**Impact:** Memory usage grows with number of unique aggregates.

**Workaround:** Restart daemon periodically.

**Future Fix:** Implement LRU eviction.

### 4. SQLite Locking on High Write Volume

**Issue:** Single writer (projection) can block reads (queries).

**Impact:** Query latency spikes during high event rate.

**Workaround:** Use WAL mode.

**Future Fix:** Shard read models by query pattern.

## Benchmarking Against Alternatives

### vs. EventStoreDB

| Metric | ReckonDB (hecate) | EventStoreDB |
|--------|-------------------|--------------|
| Throughput | ~500-1000 ops/sec | ~5000 ops/sec |
| Write latency (P95) | ~10-50ms | ~5-10ms |
| Projection lag | ~50-100ms | ~10-50ms |
| Deployment | Embedded | Standalone cluster |
| Durability | Fsync per event | Tunable |

**Analysis:**
- EventStoreDB is faster but requires separate infrastructure
- ReckonDB is simpler (embedded) but lower throughput
- For AI agent workloads (<1000 ops/sec), ReckonDB is adequate

### vs. PostgreSQL Event Sourcing

| Metric | ReckonDB | PostgreSQL (pg-event) |
|--------|----------|----------------------|
| Throughput | ~500-1000 ops/sec | ~2000-3000 ops/sec |
| Query latency | ~5-10ms | ~1-5ms |
| Durability | Guaranteed | Guaranteed |
| Ops complexity | Low (embedded) | Medium (requires DB) |

**Analysis:**
- PostgreSQL has better query performance (SQL indexes)
- ReckonDB has simpler deployment (no external DB)
- For prototype/MVP, ReckonDB is sufficient

## Recommendations

### For Typical Agent Workloads (<100 ops/sec)

- Use default configuration
- Enable WAL mode for SQLite
- Monitor projection lag

### For High-Volume Workloads (>500 ops/sec)

- Enable event batching in ReckonDB
- Use async mesh publishing
- Batch projection updates
- Monitor CPU and disk I/O

### For Production Deployments

- Enable all optimizations
- Set up monitoring (Prometheus + Grafana)
- Run performance tests in staging
- Implement backpressure at API layer
- Plan for horizontal scaling of query services

## Future Work

- [ ] Implement aggregate snapshotting
- [ ] Add event batching to mesh projections
- [ ] Implement backpressure in subscription layer
- [ ] Add LRU eviction for aggregate cache
- [ ] Support distributed ReckonDB (multi-node)
- [ ] Shard aggregates by ID range
- [ ] Add Prometheus metrics export
- [ ] Implement read-through cache for queries
- [ ] Support event archival (cold storage)
- [ ] Add circuit breaker for external calls

## References

- ReckonDB documentation: `hexdocs.pm/reckon_db`
- Evoq documentation: `hexdocs.pm/evoq`
- SQLite performance tuning: `sqlite.org/pragma.html`
- Erlang profiling: `erlang.org/doc/efficiency_guide/profiling.html`
