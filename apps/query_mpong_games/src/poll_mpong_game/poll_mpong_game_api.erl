%%%-------------------------------------------------------------------
%%% @doc GET /api/mpong/games/:game_id/state — poll current engine state.
%%%
%%% Returns the latest tick state from ETS. Frontend polls at ~10Hz.
%%% @end
%%%-------------------------------------------------------------------
-module(poll_mpong_game_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mpong/games/:game_id/state", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            GameId = cowboy_req:binding(game_id, Req0),
            case project_mpong_games_store:get_engine_state(GameId) of
                {ok, EngineState} ->
                    Body = json:encode(EngineState),
                    Req = cowboy_req:reply(200,
                        #{<<"content-type">> => <<"application/json">>,
                          <<"cache-control">> => <<"no-cache">>},
                        Body, Req0),
                    {ok, Req, State};
                {error, not_found} ->
                    Req = cowboy_req:reply(404,
                        #{<<"content-type">> => <<"application/json">>},
                        json:encode(#{ok => false, error => <<"no_engine_state">>}),
                        Req0),
                    {ok, Req, State}
            end;
        _ ->
            Req = cowboy_req:reply(405,
                #{<<"content-type">> => <<"application/json">>},
                json:encode(#{ok => false, error => <<"method_not_allowed">>}),
                Req0),
            {ok, Req, State}
    end.
