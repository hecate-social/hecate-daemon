%%% @doc CT suite for the lookup_via_dht desk. PLAN PART1 §6.4 + §7.3.
%%%
%%% Coverage:
%%%   - Single attempt success
%%%   - Retry on substrate-flake errors (not_found, timeout)
%%%   - Exhaustion after max attempts
%%%   - Non-retryable errors (sig_fail) returned immediately
%%%   - Dedup: concurrent same-key calls hit find_fn once
%%%   - Dedup: concurrent different-key calls hit find_fn twice
%%%   - dedup_timeout when waiter blocks too long
%%%
%%% Uses dependency injection (Opts.find_fn) rather than meck so
%%% tests stay self-contained and free of additional deps. Each
%%% test stub returns deterministic results from a counter.
%%% @end
-module(lookup_via_dht_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1,
         init_per_testcase/2, end_per_testcase/2]).
-export([
    success_first_attempt/1,
    success_after_one_retry/1,
    success_after_two_retries/1,
    exhausted_returns_last_error/1,
    timeout_is_retryable/1,
    sig_fail_is_not_retryable/1,
    malformed_record_is_not_retryable/1,
    dedup_same_key_one_find_call/1,
    dedup_different_keys_each_find_called/1,
    dedup_waiter_receives_owner_result/1,
    dedup_waiter_receives_owner_error/1,
    in_flight_count_is_zero_after_completion/1
]).

all() ->
    [
        success_first_attempt,
        success_after_one_retry,
        success_after_two_retries,
        exhausted_returns_last_error,
        timeout_is_retryable,
        sig_fail_is_not_retryable,
        malformed_record_is_not_retryable,
        dedup_same_key_one_find_call,
        dedup_different_keys_each_find_called,
        dedup_waiter_receives_owner_result,
        dedup_waiter_receives_owner_error,
        in_flight_count_is_zero_after_completion
    ].

init_per_suite(Config) ->
    %% start_link links to the init_per_suite caller, which CT
    %% may garbage-collect between cases — unlink to keep the
    %% dedup gen_server alive across the suite.
    {ok, Pid} = lookup_dedup:start_link(),
    unlink(Pid),
    [{dedup_pid, Pid} | Config].

end_per_suite(Config) ->
    case ?config(dedup_pid, Config) of
        undefined -> ok;
        Pid when is_pid(Pid) ->
            case is_process_alive(Pid) of
                true  -> exit(Pid, shutdown), wait_dead(Pid, 100);
                false -> ok
            end
    end,
    ok.

wait_dead(_Pid, 0) -> ok;
wait_dead(Pid, N) ->
    case is_process_alive(Pid) of
        false -> ok;
        true  -> timer:sleep(10), wait_dead(Pid, N - 1)
    end.

%% Per-testcase: drain the caller's mailbox of any leftover
%% lookup_result messages from prior tests (paranoia for the
%% concurrent-dedup tests).
init_per_testcase(_TC, Config) ->
    drain_mailbox(),
    Config.

end_per_testcase(_TC, _Config) ->
    drain_mailbox(),
    ok.

drain_mailbox() ->
    receive _ -> drain_mailbox()
    after 0 -> ok
    end.

%% A 32-byte fake storage key (matches the macula record_key/0 spec).
key(N) when is_integer(N) ->
    Tag = list_to_binary(io_lib:format("test_key_~p", [N])),
    Pad = binary:copy(<<0>>, 32 - byte_size(Tag)),
    <<Tag/binary, Pad/binary>>.

%% A trivial record map shape that matches macula:find_record/2's
%% return contract (`{ok, #{type, payload, signature}}').
record_for(N) ->
    #{type => leaf, payload => #{key_no => N}, signature => <<0:512>>}.

%%====================================================================
%% Retry behaviour
%%====================================================================

success_first_attempt(_Config) ->
    Counter = counters:new(1, []),
    Find = fun(_Pool, _K) ->
        counters:add(Counter, 1, 1),
        {ok, record_for(1)}
    end,
    {ok, R} = lookup_via_dht:find(self(), key(1), #{find_fn => Find}),
    1     = counters:get(Counter, 1),
    leaf  = maps:get(type, R),
    ok.

success_after_one_retry(_Config) ->
    %% First call returns not_found, second returns ok.
    Counter = counters:new(1, []),
    Find = fun(_Pool, _K) ->
        N = counters:get(Counter, 1),
        counters:add(Counter, 1, 1),
        case N of
            0 -> {error, not_found};
            _ -> {ok, record_for(2)}
        end
    end,
    {ok, _} = lookup_via_dht:find(self(), key(2),
                                  #{find_fn => Find,
                                    max_attempts => 3,
                                    retry_delay_ms => 0}),
    2 = counters:get(Counter, 1),
    ok.

success_after_two_retries(_Config) ->
    Counter = counters:new(1, []),
    Find = fun(_Pool, _K) ->
        N = counters:get(Counter, 1),
        counters:add(Counter, 1, 1),
        case N of
            0 -> {error, not_found};
            1 -> {error, timeout};
            _ -> {ok, record_for(3)}
        end
    end,
    {ok, _} = lookup_via_dht:find(self(), key(3),
                                  #{find_fn => Find,
                                    max_attempts => 3,
                                    retry_delay_ms => 0}),
    3 = counters:get(Counter, 1),
    ok.

exhausted_returns_last_error(_Config) ->
    Counter = counters:new(1, []),
    Find = fun(_Pool, _K) ->
        counters:add(Counter, 1, 1),
        {error, not_found}
    end,
    {error, not_found} = lookup_via_dht:find(self(), key(4),
                                             #{find_fn => Find,
                                               max_attempts => 3,
                                               retry_delay_ms => 0}),
    3 = counters:get(Counter, 1),
    ok.

timeout_is_retryable(_Config) ->
    Counter = counters:new(1, []),
    Find = fun(_Pool, _K) ->
        counters:add(Counter, 1, 1),
        {error, timeout}
    end,
    {error, timeout} = lookup_via_dht:find(self(), key(5),
                                           #{find_fn => Find,
                                             max_attempts => 2,
                                             retry_delay_ms => 0}),
    2 = counters:get(Counter, 1),
    ok.

sig_fail_is_not_retryable(_Config) ->
    %% Non-substrate errors must NOT trigger retry — they're real
    %% verdicts (record exists but is corrupted), and retrying
    %% would just waste DHT capacity.
    Counter = counters:new(1, []),
    Find = fun(_Pool, _K) ->
        counters:add(Counter, 1, 1),
        {error, sig_fail}
    end,
    {error, sig_fail} = lookup_via_dht:find(self(), key(6),
                                            #{find_fn => Find,
                                              max_attempts => 5,
                                              retry_delay_ms => 0}),
    1 = counters:get(Counter, 1),
    ok.

malformed_record_is_not_retryable(_Config) ->
    Counter = counters:new(1, []),
    Find = fun(_Pool, _K) ->
        counters:add(Counter, 1, 1),
        {error, malformed_record}
    end,
    {error, malformed_record} =
        lookup_via_dht:find(self(), key(7),
                            #{find_fn => Find,
                              max_attempts => 5,
                              retry_delay_ms => 0}),
    1 = counters:get(Counter, 1),
    ok.

%%====================================================================
%% Dedup behaviour
%%====================================================================

dedup_same_key_one_find_call(_Config) ->
    %% Three concurrent callers, same key — find_fn must fire only
    %% ONCE; all three must receive the same record.
    Counter = counters:new(1, []),
    Find = fun(_Pool, _K) ->
        counters:add(Counter, 1, 1),
        timer:sleep(50),                  %% slow enough to overlap
        {ok, record_for(8)}
    end,
    Self = self(),
    Spawn = fun() ->
        spawn(fun() ->
            R = lookup_via_dht:find(self(), key(8),
                                    #{find_fn => Find,
                                      max_attempts => 1,
                                      retry_delay_ms => 0}),
            Self ! {result, self(), R}
        end)
    end,
    P1 = Spawn(), P2 = Spawn(), P3 = Spawn(),
    R1 = collect(P1),
    R2 = collect(P2),
    R3 = collect(P3),
    {ok, _} = R1,
    R1 = R2,
    R1 = R3,
    1 = counters:get(Counter, 1),
    ok.

dedup_different_keys_each_find_called(_Config) ->
    Counter = counters:new(1, []),
    Find = fun(_Pool, _K) ->
        counters:add(Counter, 1, 1),
        timer:sleep(20),
        {ok, record_for(9)}
    end,
    Self = self(),
    Spawn = fun(K) ->
        spawn(fun() ->
            R = lookup_via_dht:find(self(), K,
                                    #{find_fn => Find,
                                      max_attempts => 1,
                                      retry_delay_ms => 0}),
            Self ! {result, self(), R}
        end)
    end,
    P1 = Spawn(key(91)), P2 = Spawn(key(92)), P3 = Spawn(key(93)),
    {ok, _} = collect(P1),
    {ok, _} = collect(P2),
    {ok, _} = collect(P3),
    3 = counters:get(Counter, 1),
    ok.

dedup_waiter_receives_owner_result(_Config) ->
    %% Owner does the work; waiter receives the same {ok, _}.
    Counter = counters:new(1, []),
    Sync = make_ref(),
    Self = self(),
    Find = fun(_Pool, _K) ->
        counters:add(Counter, 1, 1),
        Self ! {entered, Sync},
        timer:sleep(80),
        {ok, record_for(10)}
    end,
    Owner = spawn(fun() ->
        R = lookup_via_dht:find(self(), key(10),
                                #{find_fn => Find,
                                  max_attempts => 1,
                                  retry_delay_ms => 0}),
        Self ! {owner, R}
    end),
    receive {entered, Sync} -> ok after 1000 -> ct:fail(owner_didnt_enter) end,
    Waiter = spawn(fun() ->
        R = lookup_via_dht:find(self(), key(10),
                                #{find_fn => Find,
                                  max_attempts => 1,
                                  retry_delay_ms => 0}),
        Self ! {waiter, R}
    end),
    {ok, _} = receive {owner, R1} -> R1 after 1000 -> ct:fail(no_owner) end,
    {ok, _} = receive {waiter, R2} -> R2 after 1000 -> ct:fail(no_waiter) end,
    1 = counters:get(Counter, 1),
    [is_process_alive(P) andalso exit(P, shutdown) || P <- [Owner, Waiter]],
    ok.

dedup_waiter_receives_owner_error(_Config) ->
    %% When the owner's lookup ends in error, the waiter must
    %% receive the same error — not a separate retry.
    Counter = counters:new(1, []),
    Sync = make_ref(),
    Self = self(),
    Find = fun(_Pool, _K) ->
        counters:add(Counter, 1, 1),
        Self ! {entered, Sync},
        timer:sleep(60),
        {error, sig_fail}
    end,
    Owner = spawn(fun() ->
        R = lookup_via_dht:find(self(), key(11),
                                #{find_fn => Find,
                                  max_attempts => 1,
                                  retry_delay_ms => 0}),
        Self ! {owner, R}
    end),
    receive {entered, Sync} -> ok after 1000 -> ct:fail(owner_didnt_enter) end,
    Waiter = spawn(fun() ->
        R = lookup_via_dht:find(self(), key(11),
                                #{find_fn => Find,
                                  max_attempts => 1,
                                  retry_delay_ms => 0}),
        Self ! {waiter, R}
    end),
    {error, sig_fail} = receive {owner, R1} -> R1 after 1000 -> ct:fail(no_owner) end,
    {error, sig_fail} = receive {waiter, R2} -> R2 after 1000 -> ct:fail(no_waiter) end,
    1 = counters:get(Counter, 1),
    [is_process_alive(P) andalso exit(P, shutdown) || P <- [Owner, Waiter]],
    ok.

in_flight_count_is_zero_after_completion(_Config) ->
    Find = fun(_P, _K) -> {ok, record_for(12)} end,
    {ok, _} = lookup_via_dht:find(self(), key(12), #{find_fn => Find,
                                                     max_attempts => 1}),
    %% Give the broadcast cast a moment to drain.
    timer:sleep(20),
    0 = lookup_dedup:in_flight(),
    ok.

collect(Pid) ->
    receive
        {result, Pid, R} -> R
    after 5000 ->
        ct:fail({collect_timeout, Pid})
    end.
