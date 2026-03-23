%%%-------------------------------------------------------------------
%%% @doc GET /api/mpong/games — list active MPong games.
%%% @end
%%%-------------------------------------------------------------------
-module(list_mpong_games_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mpong/games", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> method_not_allowed(Req0, State)
    end.

handle_get(Req0, State) ->
    Games = project_mpong_games_store:list_active(),
    Body = json:encode(#{ok => true, games => Games}),
    Req = cowboy_req:reply(200,
        #{<<"content-type">> => <<"application/json">>},
        Body, Req0),
    {ok, Req, State}.

method_not_allowed(Req0, State) ->
    Req = cowboy_req:reply(405,
        #{<<"content-type">> => <<"application/json">>},
        json:encode(#{ok => false, error => <<"method_not_allowed">>}),
        Req0),
    {ok, Req, State}.
