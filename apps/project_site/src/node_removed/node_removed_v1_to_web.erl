%%% @doc Emitter: node_removed_v1 -> web frontend via SSE.
%%%
%%% Broadcasts the full site state to connected web clients when a node
%%% is removed. The frontend receives a `site_changed` event and updates
%%% its store reactively.
%%% @end
-module(node_removed_v1_to_web).
-behaviour(evoq_event_handler).
-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"node_removed_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, #{data := Data}, _Metadata, State) ->
    NodeName = hecate_api_utils:get_field(node_name, Data),
    case project_site_store:get() of
        {ok, Site} ->
            hecate_web_events:broadcast(site_changed, Site#{
                reason => <<"node_removed">>,
                node_name => NodeName
            });
        _ ->
            ok
    end,
    {ok, State};
handle_event(_EventType, _Event, _Metadata, State) ->
    {ok, State}.
