%%% @doc Handler for end_game command
-module(maybe_end_game).

-export([handle/1, handle_from_map/1, dispatch/2]).

-dialyzer({nowarn_function, [dispatch/2, handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    GameId = maps:get(game_id, Payload, <<>>),
    WinnerNodeId = maps:get(winner_node_id, Payload, undefined),
    Reason = maps:get(reason, Payload, <<"forced">>),
    Cmd = end_game_v1:new(GameId, WinnerNodeId, Reason),
    handle(Cmd).

-spec handle(end_game_v1:end_game_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{game_id := GameId} = end_game_v1:to_map(Command),
    case byte_size(GameId) of
        0 -> {error, game_id_required};
        _ ->
            CmdMap = end_game_v1:to_map(Command),
            Event = CmdMap#{
                event_type => <<"game_ended_v1">>,
                ended_at => erlang:system_time(millisecond)
            },
            {ok, [Event]}
    end.

-spec dispatch(binary(), end_game_v1:end_game_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(GameId, Cmd) ->
    StreamId = mpong_game_aggregate:stream_id(GameId),
    CmdMap = end_game_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = end_game,
        aggregate_type = mpong_game_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => end_game},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => mpong_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
