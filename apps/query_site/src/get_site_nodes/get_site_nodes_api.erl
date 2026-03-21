%%% @doc API handler: GET /api/site/nodes
%%%
%%% Returns the list of admitted nodes.
-module(get_site_nodes_api).
-export([init/2, routes/0]).

routes() -> [{"/api/site/nodes", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    {ok, Nodes} = project_site_store:get_nodes(),
    NodeList = maps:fold(fun(Name, #{admitted_at := AAt}, Acc) ->
        [#{node_name => Name, admitted_at => AAt} | Acc]
    end, [], Nodes),
    hecate_api_utils:json_ok(#{
        nodes => NodeList,
        count => length(NodeList)
    }, Req0).
