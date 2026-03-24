%%%-------------------------------------------------------------------
%%% @doc POST /api/mpong/lobby/open — open a new MPong lobby.
%%%
%%% Uses the local node's champion. Returns lobby info.
%%% @end
%%%-------------------------------------------------------------------
-module(open_mpong_lobby_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mpong/lobby/open", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ ->
            Req = cowboy_req:reply(405,
                #{<<"content-type">> => <<"application/json">>},
                json:encode(#{ok => false, error => <<"method_not_allowed">>}),
                Req0),
            {ok, Req, State}
    end.

handle_post(Req0, State) ->
    {ok, RawBody, Req1} = cowboy_req:read_body(Req0),
    Body = json:decode(RawBody),
    MaxPlayers = maps:get(<<"max_players">>, Body, 2),

    %% Get our champion
    NodeId = atom_to_binary(node()),
    case ets:lookup(mpong_champions, NodeId) of
        [{_, Champion}] ->
            GameId = generate_id(),
            Config = #{
                game_id => GameId,
                max_players => MaxPlayers,
                host_champion => Champion
            },
            case mpong_lobby_server:start_link(Config) of
                {ok, _Pid} ->
                    Resp = json:encode(#{ok => true, game_id => GameId,
                                         host_champion => maps:get(name, Champion, <<"Unknown">>)}),
                    Req = cowboy_req:reply(201,
                        #{<<"content-type">> => <<"application/json">>},
                        Resp, Req1),
                    {ok, Req, State};
                {error, Reason} ->
                    Resp = json:encode(#{ok => false, error => iolist_to_binary(io_lib:format("~p", [Reason]))}),
                    Req = cowboy_req:reply(500,
                        #{<<"content-type">> => <<"application/json">>},
                        Resp, Req1),
                    {ok, Req, State}
            end;
        [] ->
            Resp = json:encode(#{ok => false, error => <<"no_champion_registered">>}),
            Req = cowboy_req:reply(400,
                #{<<"content-type">> => <<"application/json">>},
                Resp, Req1),
            {ok, Req, State}
    end.

generate_id() ->
    binary:encode_hex(crypto:strong_rand_bytes(8), lowercase).
