%%% @doc API handler: GET /api/arcade/gladiators/stables
%%% Lists all training stables.
-module(get_stables_api).

-export([init/2]).

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            {ok, Stables} = query_snake_gladiators_store:get_stables(),
            hecate_api_utils:json_ok(200, #{stables => Stables}, Req0);
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.
