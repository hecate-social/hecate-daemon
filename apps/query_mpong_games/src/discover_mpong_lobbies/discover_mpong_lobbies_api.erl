%%%-------------------------------------------------------------------
%%% @doc GET /api/mpong/lobbies — discover open lobbies on the LAN cluster.
%%% @end
%%%-------------------------------------------------------------------
-module(discover_mpong_lobbies_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mpong/lobbies", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            Lobbies = discover(),
            Body = json:encode(#{ok => true, lobbies => Lobbies}),
            Req = cowboy_req:reply(200,
                #{<<"content-type">> => <<"application/json">>},
                Body, Req0),
            {ok, Req, State};
        _ ->
            Req = cowboy_req:reply(405,
                #{<<"content-type">> => <<"application/json">>},
                json:encode(#{ok => false, error => <<"method_not_allowed">>}),
                Req0),
            {ok, Req, State}
    end.

discover() ->
    Members = try pg:get_members(pg, mpong_lobby) catch _:_ -> [] end,
    lists:filtermap(fun(Pid) ->
        try
            Info = gen_server:call(Pid, get_info, 2000),
            {true, Info}
        catch _:_ ->
            false
        end
    end, Members).
