%%% @doc Handler for start_game command
-module(maybe_start_game).

-export([handle_from_map/1, dispatch/2]).

-include_lib("evoq/include/evoq.hrl").

-dialyzer({nowarn_function, [dispatch/2]}).

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    GameId = maps:get(game_id, Payload, <<>>),
    PlayerCount = maps:get(player_count, Payload, 0),
    case byte_size(GameId) of
        0 -> {error, game_id_required};
        _ ->
            Event = #{
                event_type => <<"game_started_v1">>,
                game_id => GameId,
                player_count => PlayerCount,
                started_at => erlang:system_time(millisecond)
            },
            {ok, [Event]}
    end.

-spec dispatch(binary(), start_game_v1:start_game_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(GameId, Cmd) ->
    StreamId = mpong_game_aggregate:stream_id(GameId),
    CmdMap = start_game_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = start_game,
        aggregate_type = mpong_game_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => start_game},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => mpong_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
