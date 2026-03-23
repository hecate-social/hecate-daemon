%%% @doc Handler for leave_game command
-module(maybe_leave_game).

-export([handle_from_map/1]).

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    GameId = maps:get(game_id, Payload, <<>>),
    PlayerNodeId = maps:get(player_node_id, Payload, <<>>),
    case {byte_size(GameId), byte_size(PlayerNodeId)} of
        {0, _} -> {error, game_id_required};
        {_, 0} -> {error, player_node_id_required};
        _ ->
            Event = #{
                event_type => <<"player_left_v1">>,
                game_id => GameId,
                player_node_id => PlayerNodeId,
                left_at => erlang:system_time(millisecond)
            },
            {ok, [Event]}
    end.
