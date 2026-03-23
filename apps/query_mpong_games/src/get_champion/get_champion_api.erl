%%%-------------------------------------------------------------------
%%% @doc GET /api/mpong/champion — get this node's champion bot.
%%% @end
%%%-------------------------------------------------------------------
-module(get_champion_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mpong/champion", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            NodeId = atom_to_binary(node()),
            case ets:lookup(mpong_champions, NodeId) of
                [{_, Champion}] ->
                    Body = json:encode(#{ok => true, champion => Champion}),
                    Req = cowboy_req:reply(200,
                        #{<<"content-type">> => <<"application/json">>},
                        Body, Req0),
                    {ok, Req, State};
                [] ->
                    Req = cowboy_req:reply(404,
                        #{<<"content-type">> => <<"application/json">>},
                        json:encode(#{ok => false, error => <<"no_champion">>}),
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
