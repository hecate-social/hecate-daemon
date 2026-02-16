%%% @doc API handler: GET /api/node/mesh/graph
-module(get_mesh_graph_api).
-export([init/2, routes/0]).

routes() -> [{"/api/node/mesh/graph", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case get_mesh_graph:get() of
        {ok, Graph} ->
            hecate_api_utils:json_ok(Graph, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
