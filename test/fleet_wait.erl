%%% @doc Wait helpers for fleet tests.
%%%
%%% The fleet's eventual-consistency makes naive sequential code
%%% fragile (event has to round-trip relay → realm → relay → peer →
%%% projection). These helpers provide structured polling with sane
%%% defaults + clear failure messages.
%%% @end
-module(fleet_wait).

-export([until/1, until/2, until/3]).
-export([for_status/3, for_state/4]).

-define(DEFAULT_TIMEOUT_MS, 30000).
-define(DEFAULT_POLL_MS, 500).

%% @doc Wait until `Fn()` returns true (or a non-false truthy value).
%% Times out after `?DEFAULT_TIMEOUT_MS`. ct:fail on timeout.
until(Fn) -> until(Fn, ?DEFAULT_TIMEOUT_MS, ?DEFAULT_POLL_MS).

until(Fn, TimeoutMs) -> until(Fn, TimeoutMs, ?DEFAULT_POLL_MS).

until(Fn, TimeoutMs, PollMs) ->
    Deadline = erlang:system_time(millisecond) + TimeoutMs,
    until_loop(Fn, Deadline, PollMs).

until_loop(Fn, Deadline, PollMs) ->
    case Fn() of
        true        -> ok;
        {ok, _} = R -> R;
        false ->
            now_check_deadline(Fn, Deadline, PollMs);
        _Other ->
            now_check_deadline(Fn, Deadline, PollMs)
    end.

now_check_deadline(Fn, Deadline, PollMs) ->
    Now = erlang:system_time(millisecond),
    case Now > Deadline of
        true  -> ct:fail({fleet_wait_timeout, Fn});
        false -> timer:sleep(PollMs),
                 until_loop(Fn, Deadline, PollMs)
    end.

%% @doc Wait until a fleet daemon endpoint returns the given status
%% code. Useful for "wait until POST /download is accepted" + "wait
%% until GET /download reports 'completed'".
for_status(Daemon, Path, ExpectedStatus) ->
    until(fun() ->
        case fleet_daemon:get(Daemon, Path) of
            {ExpectedStatus, _} -> true;
            _                   -> false
        end
    end).

%% @doc Wait until a JSON field at `Path` matches `Expected`. Common
%% pattern for download progress / guard state.
for_state(Daemon, Path, Field, Expected) ->
    until(fun() ->
        case fleet_daemon:get(Daemon, Path) of
            {Status, Body} when Status >= 200, Status < 300 ->
                try json:decode(Body) of
                    M when is_map(M) -> maps:get(Field, M, undefined) =:= Expected;
                    _                -> false
                catch _:_ -> false
                end;
            _ -> false
        end
    end).
