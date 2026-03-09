%%% @doc Built-in flag-maps handler for in-VM plugins.
%%%
%%% Serves GET /plugin/{name}/api/flag-maps by calling
%%% CallbackModule:flag_maps() — no per-plugin handler needed.
%%%
%%% Response is a JSON object mapping aggregate names to their flag maps.
%%% Integer keys are converted to strings for JSON compatibility.
-module(hecate_plugin_flag_maps_handler).
-export([init/2]).

init(Req0, #{callback := Cb} = State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            FlagMaps = safe_flag_maps(Cb),
            Body = json:encode(convert_keys(FlagMaps)),
            Req1 = cowboy_req:reply(200, #{
                <<"content-type">> => <<"application/json">>,
                <<"access-control-allow-origin">> => <<"*">>
            }, Body, Req0),
            {ok, Req1, State};
        _ ->
            Req1 = cowboy_req:reply(405, #{}, <<>>, Req0),
            {ok, Req1, State}
    end.

safe_flag_maps(Cb) ->
    try Cb:flag_maps()
    catch _:_ -> #{}
    end.

%% JSON keys must be strings — convert integer flag values to binaries.
convert_keys(FlagMaps) ->
    maps:map(fun(_AggName, FlagMap) ->
        maps:fold(fun(K, V, Acc) when is_integer(K) ->
            Acc#{integer_to_binary(K) => V};
        (K, V, Acc) ->
            Acc#{K => V}
        end, #{}, FlagMap)
    end, FlagMaps).
