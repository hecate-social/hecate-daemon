%%%-------------------------------------------------------------------
%%% @doc GET /api/mpong/games/:game_id — get a single MPong game.
%%% @end
%%%-------------------------------------------------------------------
-module(get_mpong_game_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mpong/games/:game_id", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ ->
            Req = cowboy_req:reply(405,
                #{<<"content-type">> => <<"application/json">>},
                json:encode(#{ok => false, error => <<"method_not_allowed">>}),
                Req0),
            {ok, Req, State}
    end.

handle_get(Req0, State) ->
    GameId = cowboy_req:binding(game_id, Req0),
    case project_mpong_games_store:get(GameId) of
        {ok, Game} ->
            Body = json:encode(#{ok => true, game => Game}),
            Req = cowboy_req:reply(200,
                #{<<"content-type">> => <<"application/json">>},
                Body, Req0),
            {ok, Req, State};
        {error, not_found} ->
            Req = cowboy_req:reply(404,
                #{<<"content-type">> => <<"application/json">>},
                json:encode(#{ok => false, error => <<"game_not_found">>}),
                Req0),
            {ok, Req, State}
    end.
