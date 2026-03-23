%%% @doc Handler for start_game command
-module(maybe_start_game).

-export([handle_from_map/1]).

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
