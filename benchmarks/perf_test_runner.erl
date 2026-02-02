-module(perf_test_runner).
-export([run_all/0, run_scenario/1]).
-export([command_throughput_test/1, concurrent_readwrite_test/1, large_stream_test/1, projection_lag_test/1]).

-record(perf_result, {
    scenario :: atom(),
    total_ops :: non_neg_integer(),
    duration_ms :: non_neg_integer(),
    throughput :: float(),
    latency_p50 :: float(),
    latency_p95 :: float(),
    latency_p99 :: float(),
    errors :: non_neg_integer(),
    memory_bytes :: non_neg_integer()
}).

%% Public API

run_all() ->
    Scenarios = [
        command_throughput,
        concurrent_readwrite,
        large_stream,
        projection_lag
    ],
    Results = lists:map(fun run_scenario/1, Scenarios),
    print_summary(Results),
    Results.

run_scenario(Scenario) ->
    io:format("~n=== Running scenario: ~p ===~n", [Scenario]),
    StartMem = erlang:memory(total),
    StartTime = erlang:monotonic_time(millisecond),

    Result = case Scenario of
        command_throughput -> command_throughput_test(1000);
        concurrent_readwrite -> concurrent_readwrite_test(100);
        large_stream -> large_stream_test(10000);
        projection_lag -> projection_lag_test(100)
    end,

    EndTime = erlang:monotonic_time(millisecond),
    EndMem = erlang:memory(total),
    Duration = EndTime - StartTime,

    PerfResult = Result#perf_result{
        duration_ms = Duration,
        memory_bytes = EndMem - StartMem
    },

    print_result(PerfResult),
    PerfResult.

%% Test Scenarios

%% Test: High command throughput
command_throughput_test(NumCommands) ->
    io:format("Testing command throughput with ~p commands...~n", [NumCommands]),

    Latencies = lists:map(fun(N) ->
        MRI = list_to_binary(io_lib:format("mri:capability:test/perf-~p", [N])),
        AgentID = <<"did:macula:perf-agent">>,
        Tags = [<<"performance">>, <<"test">>],
        Desc = <<"Performance test capability">>,

        Cmd = announce_capability_v1:new(MRI, AgentID, Tags, Desc, undefined, #{}),

        Start = erlang:monotonic_time(microsecond),
        Result = maybe_announce_capability:dispatch(Cmd),
        End = erlang:monotonic_time(microsecond),

        case Result of
            {ok, _Version, _Events} ->
                (End - Start) / 1000.0;  % Convert to ms
            {error, _} ->
                error
        end
    end, lists:seq(1, NumCommands)),

    ValidLatencies = [L || L <- Latencies, L =/= error],
    Errors = length(Latencies) - length(ValidLatencies),

    calculate_metrics(command_throughput, NumCommands, ValidLatencies, Errors).

%% Test: Concurrent read/write operations
concurrent_readwrite_test(NumWorkers) ->
    io:format("Testing concurrent read/write with ~p workers...~n", [NumWorkers]),

    Parent = self(),
    Workers = lists:map(fun(WorkerId) ->
        spawn_link(fun() ->
            worker_loop(WorkerId, 10, Parent)
        end)
    end, lists:seq(1, NumWorkers)),

    Latencies = collect_worker_results(Workers, []),
    ValidLatencies = [L || L <- Latencies, is_float(L)],
    Errors = length(Latencies) - length(ValidLatencies),

    calculate_metrics(concurrent_readwrite, length(ValidLatencies), ValidLatencies, Errors).

worker_loop(WorkerId, 0, Parent) ->
    Parent ! {worker_done, WorkerId, []};
worker_loop(WorkerId, N, Parent) ->
    MRI = list_to_binary(io_lib:format("mri:capability:test/worker-~p-~p", [WorkerId, N])),

    %% Write
    Cmd = announce_capability_v1:new(
        MRI,
        <<"did:macula:worker">>,
        [<<"test">>],
        <<"Test">>,
        undefined,
        #{}
    ),
    Start = erlang:monotonic_time(microsecond),
    {ok, _V, _E} = maybe_announce_capability:dispatch(Cmd),
    WriteEnd = erlang:monotonic_time(microsecond),

    %% Read
    timer:sleep(10),  % Give projection time to update
    {ok, _Cap} = find_capability:execute(MRI),
    ReadEnd = erlang:monotonic_time(microsecond),

    WriteLatency = (WriteEnd - Start) / 1000.0,
    ReadLatency = (ReadEnd - WriteEnd) / 1000.0,
    TotalLatency = (ReadEnd - Start) / 1000.0,

    Latencies = [WriteLatency, ReadLatency, TotalLatency],
    worker_loop(WorkerId, N - 1, Parent).

collect_worker_results([], Acc) ->
    Acc;
collect_worker_results(Workers, Acc) ->
    receive
        {worker_done, _WorkerId, Latencies} ->
            collect_worker_results(Workers -- [_WorkerId], Acc ++ Latencies)
    after 60000 ->
        io:format("WARNING: Timeout waiting for workers~n"),
        Acc
    end.

%% Test: Large event stream
large_stream_test(NumEvents) ->
    io:format("Testing large stream with ~p events...~n", [NumEvents]),

    StreamMRI = <<"mri:capability:test/large-stream">>,

    Latencies = lists:map(fun(N) ->
        Cmd = announce_capability_v1:new(
            StreamMRI,
            list_to_binary(io_lib:format("did:macula:agent-~p", [N])),
            [<<"large-stream">>],
            list_to_binary(io_lib:format("Event ~p", [N])),
            undefined,
            #{}
        ),

        Start = erlang:monotonic_time(microsecond),
        case maybe_announce_capability:dispatch(Cmd) of
            {ok, _V, _E} ->
                End = erlang:monotonic_time(microsecond),
                (End - Start) / 1000.0;
            {error, _} ->
                error
        end
    end, lists:seq(1, NumEvents)),

    ValidLatencies = [L || L <- Latencies, L =/= error],
    Errors = length(Latencies) - length(ValidLatencies),

    calculate_metrics(large_stream, NumEvents, ValidLatencies, Errors).

%% Test: Projection lag
projection_lag_test(NumSamples) ->
    io:format("Testing projection lag with ~p samples...~n", [NumSamples]),

    Lags = lists:map(fun(N) ->
        MRI = list_to_binary(io_lib:format("mri:capability:test/lag-~p", [N])),

        Cmd = announce_capability_v1:new(
            MRI,
            <<"did:macula:lag-test">>,
            [<<"lag-test">>],
            <<"Lag test">>,
            undefined,
            #{}
        ),

        EventTime = erlang:monotonic_time(microsecond),
        {ok, _V, _E} = maybe_announce_capability:dispatch(Cmd),

        %% Poll until projection is updated
        measure_projection_lag(MRI, EventTime, 0)
    end, lists:seq(1, NumSamples)),

    ValidLags = [L || L <- Lags, L =/= error],
    Errors = length(Lags) - length(ValidLags),

    calculate_metrics(projection_lag, NumSamples, ValidLags, Errors).

measure_projection_lag(MRI, EventTime, Attempts) when Attempts > 100 ->
    error;  % Timeout after 100 attempts
measure_projection_lag(MRI, EventTime, Attempts) ->
    timer:sleep(1),  % 1ms poll interval
    case find_capability:execute(MRI) of
        {ok, _Cap} ->
            ProjectionTime = erlang:monotonic_time(microsecond),
            (ProjectionTime - EventTime) / 1000.0;  % Convert to ms
        {error, not_found} ->
            measure_projection_lag(MRI, EventTime, Attempts + 1);
        {error, _} ->
            error
    end.

%% Metrics Calculation

calculate_metrics(Scenario, TotalOps, Latencies, Errors) ->
    SortedLatencies = lists:sort(Latencies),

    P50 = percentile(SortedLatencies, 50),
    P95 = percentile(SortedLatencies, 95),
    P99 = percentile(SortedLatencies, 99),

    #perf_result{
        scenario = Scenario,
        total_ops = TotalOps,
        duration_ms = 0,  % Filled by caller
        throughput = 0.0,  % Calculated after duration known
        latency_p50 = P50,
        latency_p95 = P95,
        latency_p99 = P99,
        errors = Errors,
        memory_bytes = 0  % Filled by caller
    }.

percentile([], _) -> 0.0;
percentile(SortedList, Percentile) ->
    Index = round(length(SortedList) * Percentile / 100),
    ClampedIndex = max(1, min(Index, length(SortedList))),
    lists:nth(ClampedIndex, SortedList).

%% Output Formatting

print_result(#perf_result{} = R) ->
    Throughput = case R#perf_result.duration_ms of
        0 -> 0.0;
        DurationMs -> (R#perf_result.total_ops / DurationMs) * 1000.0
    end,

    io:format("~nResults:~n"),
    io:format("  Total operations: ~p~n", [R#perf_result.total_ops]),
    io:format("  Duration: ~p ms~n", [R#perf_result.duration_ms]),
    io:format("  Throughput: ~.2f ops/sec~n", [Throughput]),
    io:format("  Latency P50: ~.3f ms~n", [R#perf_result.latency_p50]),
    io:format("  Latency P95: ~.3f ms~n", [R#perf_result.latency_p95]),
    io:format("  Latency P99: ~.3f ms~n", [R#perf_result.latency_p99]),
    io:format("  Errors: ~p~n", [R#perf_result.errors]),
    io:format("  Memory delta: ~.2f MB~n", [R#perf_result.memory_bytes / 1024 / 1024]).

print_summary(Results) ->
    io:format("~n~n=== PERFORMANCE TEST SUMMARY ===~n"),
    io:format("~-25s ~-12s ~-12s ~-12s ~-12s~n",
              ["Scenario", "Throughput", "P50 (ms)", "P95 (ms)", "P99 (ms)"]),
    io:format("~s~n", [lists:duplicate(75, $-)]),

    lists:foreach(fun(#perf_result{} = R) ->
        Throughput = case R#perf_result.duration_ms of
            0 -> 0.0;
            DurationMs -> (R#perf_result.total_ops / DurationMs) * 1000.0
        end,
        io:format("~-25s ~-12.2f ~-12.3f ~-12.3f ~-12.3f~n",
                  [R#perf_result.scenario,
                   Throughput,
                   R#perf_result.latency_p50,
                   R#perf_result.latency_p95,
                   R#perf_result.latency_p99])
    end, Results),

    io:format("~n").
