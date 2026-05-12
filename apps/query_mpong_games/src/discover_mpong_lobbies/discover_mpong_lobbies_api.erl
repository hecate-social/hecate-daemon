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
    %% The `mpong_lobby' pg group carries BOTH lobby servers and the
    %% lobby seeker (the seeker joins it to receive lobby-open
    %% broadcasts). The seeker answers `get_info' with `ok' from its
    %% catch-all handle_call, so without a shape check the lobby list
    %% came back as `["ok","ok",...]'. Keep only the map replies
    %% (real lobby servers).
    Members = try pg:get_members(pg, mpong_lobby) catch _:_ -> [] end,
    lists:filtermap(fun(Pid) ->
        case (catch gen_server:call(Pid, get_info, 2000)) of
            Info when is_map(Info) -> {true, Info};
            _                      -> false
        end
    end, Members).
