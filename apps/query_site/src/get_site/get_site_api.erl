%%% @doc API handler: GET /api/site
%%%
%%% Returns site identity from project_site_store and live BEAM
%%% cluster membership from erlang:nodes(). NODES reflects the
%%% real-time cluster state (Layer 2), not event-sourced admissions.
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
               initiated_at := InitiatedAt, initiated_by := InitiatedBy} = Site} ->
            %% Live cluster nodes (Layer 2)
            AllNodes = [node() | nodes()],
            AdmittedNodes = maps:get(nodes, Site, #{}),
            NodeList = [node_entry(N, AdmittedNodes) || N <- AllNodes],
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

%% @private Build node entry: live cluster membership + admission metadata.
node_entry(Node, AdmittedNodes) ->
    Name = atom_to_binary(Node),
    case maps:get(Name, AdmittedNodes, undefined) of
        #{admitted_at := AAt} ->
            #{node_name => Name, admitted_at => AAt};
        _ ->
            #{node_name => Name, admitted_at => erlang:system_time(millisecond)}
    end.
