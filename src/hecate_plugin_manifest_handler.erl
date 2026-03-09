%%% @doc Built-in manifest handler for in-VM plugins.
%%%
%%% Serves GET /plugin/{name}/api/manifest by calling
%%% CallbackModule:manifest() — no per-plugin handler needed.
-module(hecate_plugin_manifest_handler).
-export([init/2]).

init(Req0, #{callback := Cb} = State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            Manifest = Cb:manifest(),
            Body = json:encode(Manifest),
            Req1 = cowboy_req:reply(200, #{
                <<"content-type">> => <<"application/json">>,
                <<"access-control-allow-origin">> => <<"*">>
            }, Body, Req0),
            {ok, Req1, State};
        _ ->
            Req1 = cowboy_req:reply(405, #{}, <<>>, Req0),
            {ok, Req1, State}
    end.
