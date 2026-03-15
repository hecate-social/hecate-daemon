%%% @doc GET /api/observer/metrics/stream — SSE real-time metrics.
%%%
%%% Long-lived Server-Sent Events connection that pushes system metrics
%%% every 2 seconds while a client is connected. Each SSE handler process
%%% collects its own metrics (no shared gen_server). Zero overhead when
%%% no client is connected.
%%% @end
-module(stream_observer_metrics_api).

-export([init/2, routes/0]).

-define(PUSH_INTERVAL_MS, 2000).

routes() -> [{"/api/observer/metrics/stream", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> start_stream(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

start_stream(Req0, _State) ->
    %% Enable scheduler wall time for utilization calculation
    erlang:system_flag(scheduler_wall_time, true),
    %% Take initial sample for delta calculation
    InitWallTime = erlang:statistics(scheduler_wall_time_all),
    {InitReductions, _} = erlang:statistics(reductions),
    {{input, InitIn}, {output, InitOut}} = erlang:statistics(io),

    Req1 = cowboy_req:stream_reply(200, #{
        <<"content-type">> => <<"text/event-stream">>,
        <<"cache-control">> => <<"no-cache">>,
        <<"connection">> => <<"keep-alive">>
    }, Req0),

    cowboy_req:stream_body(<<": connected\n\n">>, nofin, Req1),

    erlang:send_after(?PUSH_INTERVAL_MS, self(), push_metrics),

    stream_loop(Req1, #{
        prev_wall_time => InitWallTime,
        prev_reductions => InitReductions,
        prev_io_in => InitIn,
        prev_io_out => InitOut
    }).

stream_loop(Req, PrevState) ->
    receive
        push_metrics ->
            case push_snapshot(Req, PrevState) of
                {ok, NextState} ->
                    erlang:send_after(?PUSH_INTERVAL_MS, self(), push_metrics),
                    stream_loop(Req, NextState);
                {error, _} ->
                    {ok, Req, []}
            end;
        _Other ->
            stream_loop(Req, PrevState)
    end.

push_snapshot(Req, #{prev_wall_time := PrevWT, prev_reductions := PrevRed,
                      prev_io_in := PrevIn, prev_io_out := PrevOut}) ->
    %% Memory
    Memory = erlang:memory(),
    MemoryMap = #{
        total => proplists:get_value(total, Memory, 0),
        processes => proplists:get_value(processes, Memory, 0),
        system => proplists:get_value(system, Memory, 0),
        ets => proplists:get_value(ets, Memory, 0),
        binary => proplists:get_value(binary, Memory, 0)
    },

    %% Process count
    ProcessCount = erlang:system_info(process_count),

    %% Scheduler utilization (delta from previous sample)
    CurrWT = erlang:statistics(scheduler_wall_time_all),
    SchedUtil = calc_scheduler_utilization(PrevWT, CurrWT),

    %% Reductions delta
    {CurrRed, _} = erlang:statistics(reductions),
    ReductionsDelta = CurrRed - PrevRed,

    %% IO delta
    {{input, CurrIn}, {output, CurrOut}} = erlang:statistics(io),
    IoDelta = #{
        input_bytes => CurrIn - PrevIn,
        output_bytes => CurrOut - PrevOut
    },

    Snapshot = #{
        memory => MemoryMap,
        process_count => ProcessCount,
        scheduler_utilization => SchedUtil,
        reductions_delta => ReductionsDelta,
        io_delta => IoDelta,
        timestamp => erlang:system_time(millisecond)
    },

    Data = iolist_to_binary(json:encode(Snapshot)),
    Payload = <<"event: metrics\ndata: ", Data/binary, "\n\n">>,
    case catch cowboy_req:stream_body(Payload, nofin, Req) of
        ok ->
            {ok, #{
                prev_wall_time => CurrWT,
                prev_reductions => CurrRed,
                prev_io_in => CurrIn,
                prev_io_out => CurrOut
            }};
        _ ->
            {error, disconnected}
    end.

calc_scheduler_utilization(Prev, Curr) ->
    %% Match scheduler IDs between samples
    PrevMap = maps:from_list([{Id, {A, T}} || {Id, A, T} <- Prev]),
    lists:filtermap(fun({Id, Active2, Total2}) ->
        case maps:find(Id, PrevMap) of
            {ok, {Active1, Total1}} ->
                DeltaActive = Active2 - Active1,
                DeltaTotal = Total2 - Total1,
                Util = case DeltaTotal of
                    0 -> 0.0;
                    _ -> (DeltaActive / DeltaTotal) * 100.0
                end,
                {true, #{scheduler => Id, utilization => round_float(Util)}};
            error ->
                false
        end
    end, Curr).

round_float(F) ->
    round(F * 100) / 100.
