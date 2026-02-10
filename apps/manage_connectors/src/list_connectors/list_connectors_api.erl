-module(list_connectors_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    hecate_api_utils:json_ok(#{
        connectors => [],
        message => <<"Use query_connectors service for full listing">>
    }, Req0).
