%%% @doc Built-in health handler for in-VM plugins.
%%%
%%% Serves GET /plugin/{name}/api/health by calling
%%% CallbackModule:health() (optional) and CallbackModule:manifest().
%%% Returns JSON with ok/degraded/unhealthy status, version, app name, and node.
-module(hecate_plugin_health_handler).
-export([init/2]).

init(Req0, #{callback := Cb} = State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            Manifest = Cb:manifest(),
            Health = safe_health(Cb),
            Body = json:encode(health_response(Health, Manifest)),
            Req1 = cowboy_req:reply(200, #{
                <<"content-type">> => <<"application/json">>,
                <<"access-control-allow-origin">> => <<"*">>
            }, Body, Req0),
            {ok, Req1, State};
        _ ->
            Req1 = cowboy_req:reply(405, #{}, <<>>, Req0),
            {ok, Req1, State}
    end.

safe_health(Cb) ->
    case erlang:function_exported(Cb, health, 0) of
        true ->
            try Cb:health()
            catch _:_ -> ok
            end;
        false ->
            ok
    end.

health_response(ok, Manifest) ->
    #{
        <<"ok">> => true,
        <<"app">> => maps:get(name, Manifest, <<>>),
        <<"version">> => maps:get(version, Manifest, <<"0.0.0">>),
        <<"node">> => atom_to_binary(node(), utf8)
    };
health_response(degraded, Manifest) ->
    #{
        <<"ok">> => true,
        <<"app">> => maps:get(name, Manifest, <<>>),
        <<"version">> => maps:get(version, Manifest, <<"0.0.0">>),
        <<"node">> => atom_to_binary(node(), utf8),
        <<"status">> => <<"degraded">>
    };
health_response({unhealthy, Reason}, Manifest) ->
    #{
        <<"ok">> => false,
        <<"app">> => maps:get(name, Manifest, <<>>),
        <<"version">> => maps:get(version, Manifest, <<"0.0.0">>),
        <<"node">> => atom_to_binary(node(), utf8),
        <<"error">> => Reason
    }.
