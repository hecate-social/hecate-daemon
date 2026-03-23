%%% @doc Handler for eliminate_player command
-module(maybe_eliminate_player).

-export([handle_from_map/1, dispatch/2]).

-dialyzer({nowarn_function, [dispatch/2]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    GameId = maps:get(game_id, Payload, <<>>),
    PlayerNodeId = maps:get(player_node_id, Payload, <<>>),
    Reason = maps:get(reason, Payload, <<"ball_missed">>),
    RemainingCount = maps:get(remaining_count, Payload, 0),
    case {byte_size(GameId), byte_size(PlayerNodeId)} of
        {0, _} -> {error, game_id_required};
        {_, 0} -> {error, player_node_id_required};
        _ ->
            Event = #{
                event_type => <<"player_eliminated_v1">>,
                game_id => GameId,
                player_node_id => PlayerNodeId,
                reason => Reason,
                eliminated_at => erlang:system_time(millisecond),
                remaining_count => RemainingCount
            },
            {ok, [Event]}
    end.

-spec dispatch(binary(), eliminate_player_v1:eliminate_player_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(GameId, Cmd) ->
    StreamId = mpong_game_aggregate:stream_id(GameId),
    CmdMap = eliminate_player_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = eliminate_player,
        aggregate_type = mpong_game_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => eliminate_player},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => mpong_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
