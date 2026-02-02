# Performance Test Suite Implementation Notes

## Created Files

1. **perf_test_runner.erl** - Main performance test harness
   - 4 test scenarios: command_throughput, concurrent_readwrite, large_stream, projection_lag
   - Metrics collection: throughput, latency percentiles (P50, P95, P99), errors, memory usage
   - Summary reporting with formatted output

2. **README.md** - Comprehensive test documentation
   - Test scenario descriptions
   - Acceptance criteria
   - Running instructions
   - Troubleshooting guide
   - CI integration guide

3. **run_perf_tests.sh** - Automated test runner script
   - Compiles project
   - Starts all applications
   - Runs tests (all or specific scenario)
   - Easy-to-use CLI interface

4. **check_perf_thresholds.sh** - CI threshold checking
   - Template for performance regression detection
   - Configurable thresholds
   - Exit codes for CI integration

5. **docs/PERFORMANCE.md** - Performance characteristics documentation
   - Architecture overview
   - Performance targets
   - Bottleneck analysis
   - Optimization strategies
   - Scaling recommendations
   - Monitoring guide

## Test Scenarios

### 1. Command Throughput (1000 commands)
Tests sustained command dispatch throughput with sequential operations.

**Target:** > 500 commands/sec, P95 latency < 50ms

### 2. Concurrent Read/Write (100 workers x 10 ops)
Tests concurrent operations with multiple workers performing write-then-read cycles.

**Target:** No deadlocks, read latency < 10ms (P95)

### 3. Large Stream (10,000 events)
Tests performance degradation with large event streams.

**Target:** Stable latency (P99 < 100ms), linear scaling

### 4. Projection Lag (100 samples)
Measures time from event storage to queryable read model.

**Target:** Projection lag < 100ms (P95)

## Usage

### Quick Start

```bash
cd test/performance
./run_perf_tests.sh
```

### Specific Scenario

```bash
./run_perf_tests.sh command_throughput
./run_perf_tests.sh concurrent_readwrite
./run_perf_tests.sh large_stream
./run_perf_tests.sh projection_lag
```

### Via Erlang Shell

```erlang
c(perf_test_runner).
perf_test_runner:run_all().
```

## Metrics Collected

- **Total operations**: Count of operations performed
- **Duration**: Wall-clock time (ms)
- **Throughput**: Operations per second
- **Latency P50/P95/P99**: Percentiles in milliseconds
- **Errors**: Failed operation count
- **Memory delta**: Memory used during test (MB)

## Current Status

**Infrastructure:** ✅ Complete

**Baseline Numbers:** ⏳ Pending (requires running system)

To establish baseline:
1. Start all applications
2. Run: `./run_perf_tests.sh`
3. Update `docs/PERFORMANCE.md` with actual numbers
4. Update `README.md` performance baseline table

## Integration with CI/CD

### GitHub Actions Example

```yaml
# .github/workflows/performance.yml
name: Performance Tests
on:
  push:
    branches: [main]
  pull_request:

jobs:
  perf:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          otp-version: '26'
      - run: rebar3 compile
      - run: cd test/performance && ./run_perf_tests.sh
      - run: ./check_perf_thresholds.sh results.json
```

## Next Steps

1. ✅ Performance test infrastructure created
2. ⏳ Run tests on operational system
3. ⏳ Establish baseline performance numbers
4. ⏳ Identify and fix bottlenecks
5. ⏳ Document recommended limits
6. ⏳ Add to CI/CD pipeline

## Known Limitations

- Tests currently focus on `manage_capabilities` domain only
- No multi-domain stress testing yet
- Memory profiling not yet integrated
- Disk I/O monitoring not automated
- Results not persisted (manual capture needed)

## Future Enhancements

- [ ] Add tests for all 6 domains
- [ ] Multi-domain concurrent testing
- [ ] Memory profiling with `recon`
- [ ] Disk I/O tracking
- [ ] Automated result persistence (JSON/CSV)
- [ ] Trend analysis over time
- [ ] Grafana dashboard integration
- [ ] Soak tests (hours/days duration)
- [ ] Chaos testing (process failures)
