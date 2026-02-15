%%% @doc maybe_start_duel handler
%%% Business logic for starting a snake duel.
%%% Creates the duel event and spawns the duel process.
-module(maybe_start_duel).

-export([handle/1, dispatch/1]).

%% @doc Handle start_duel_v1 command — creates event and spawns duel proc
-spec handle(start_duel_v1:start_duel_v1()) ->
    {ok, [duel_started_v1:duel_started_v1()]} | {error, term()}.
handle(Cmd) ->
    MatchId = start_duel_v1:get_match_id(Cmd),
    AF1 = start_duel_v1:get_af1(Cmd),
    AF2 = start_duel_v1:get_af2(Cmd),
    TickMs = start_duel_v1:get_tick_ms(Cmd),

    %% Validate
    case validate(AF1, AF2, TickMs) of
        ok ->
            Event = duel_started_v1:new(#{
                match_id => MatchId,
                af1 => AF1,
                af2 => AF2,
                tick_ms => TickMs
            }),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch — spawns duel process (no event store for duels,
%% they're ephemeral live games). Returns match_id and pid.
-spec dispatch(start_duel_v1:start_duel_v1()) ->
    {ok, binary(), pid()} | {error, term()}.
dispatch(Cmd) ->
    case handle(Cmd) of
        {ok, _Events} ->
            MatchId = start_duel_v1:get_match_id(Cmd),
            Config = #{
                match_id => MatchId,
                af1 => start_duel_v1:get_af1(Cmd),
                af2 => start_duel_v1:get_af2(Cmd),
                tick_ms => start_duel_v1:get_tick_ms(Cmd)
            },
            case duel_proc_sup:start_duel(Config) of
                {ok, Pid} -> {ok, MatchId, Pid};
                {error, Reason} -> {error, Reason}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal
validate(AF1, AF2, TickMs) when
    is_integer(AF1), AF1 >= 0, AF1 =< 100,
    is_integer(AF2), AF2 >= 0, AF2 =< 100,
    is_integer(TickMs), TickMs >= 50, TickMs =< 1000 ->
    ok;
validate(_, _, _) ->
    {error, invalid_parameters}.
