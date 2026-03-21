%%% @doc API handler: GET /api/site
%%%
%%% Returns site identity and nodes from project_site_store.
-module(get_site_api).
-export([init/2, routes/0]).

routes() -> [{"/api/site", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case project_site_store:get() of
        {ok, #{site_id := SiteId, status := Status, status_label := StatusLabel,
               initiated_at := InitiatedAt, initiated_by := InitiatedBy,
               nodes := Nodes}} ->
            NodeList = maps:fold(fun(Name, #{admitted_at := AAt}, Acc) ->
                [#{node_name => Name, admitted_at => AAt} | Acc]
            end, [], Nodes),
            hecate_api_utils:json_ok(#{
                site_id => SiteId,
                status => Status,
                status_label => StatusLabel,
                initiated_at => InitiatedAt,
                initiated_by => InitiatedBy,
                node_count => length(NodeList),
                nodes => NodeList
            }, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"Site not initialized">>, Req0)
    end.
