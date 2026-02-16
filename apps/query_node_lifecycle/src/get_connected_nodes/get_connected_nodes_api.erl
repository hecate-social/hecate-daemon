%%% @doc API handler: GET /api/node/mesh/connected?source=...
-module(get_connected_nodes_api).
-export([init/2, routes/0]).

routes() -> [{"/api/node/mesh/connected", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    QS = cowboy_req:parse_qs(Req0),
    case proplists:get_value(<<"source">>, QS) of
        undefined ->
            hecate_api_utils:bad_request(<<"Missing 'source' query parameter">>, Req0);
        SourceNode ->
            case get_connected_nodes:get(SourceNode) of
                {ok, Nodes} ->
                    hecate_api_utils:json_ok(#{
                        nodes => Nodes,
                        count => length(Nodes),
                        source_node => SourceNode
                    }, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req0)
            end
    end.
