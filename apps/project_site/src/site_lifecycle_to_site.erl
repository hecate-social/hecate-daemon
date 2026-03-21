%%% @doc Merged projection: site lifecycle events -> site ETS.
%%%
%%% Handles site identity + node events in a single projection.
%%% Realm memberships are separate (stay in realm_memberships_store).
%%% @end
-module(site_lifecycle_to_site).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, site).
-define(KEY, site).

interested_in() ->
    [<<"site_initiated_v1">>,
     <<"node_admitted_v1">>,
     <<"node_removed_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = Event, _Metadata, State, RM) ->
    case get_event_type(Event) of
        <<"site_initiated_v1">>  -> project_initiated(Data, State, RM);
        <<"node_admitted_v1">>   -> project_node_admitted(Data, State, RM);
        <<"node_removed_v1">>    -> project_node_removed(Data, State, RM);
        _                        -> {ok, State, RM}
    end.

%% --- Initiated: create site entry ---

project_initiated(Data, State, RM) ->
    Entry = #{
        site_id      => gf(site_id, Data),
        initiated_by => gf(initiated_by, Data),
        initiated_at => gf(initiated_at, Data),
        nodes        => #{},
        status       => 1,
        status_label => <<"Initiated">>
    },
    {ok, RM2} = evoq_read_model:put(?KEY, Entry, RM),
    {ok, State, RM2}.

%% --- Node admitted: add to nodes map ---

project_node_admitted(Data, State, RM) ->
    case ets:lookup(?TABLE, ?KEY) of
        [{_, #{nodes := Nodes} = Existing}] ->
            NodeName = gf(node_name, Data),
            AdmittedAt = gf(admitted_at, Data),
            NewNodes = maps:put(NodeName, #{admitted_at => AdmittedAt}, Nodes),
            Updated = Existing#{nodes => NewNodes},
            {ok, RM2} = evoq_read_model:put(?KEY, Updated, RM),
            {ok, State, RM2};
        [] ->
            {ok, State, RM}
    end.

%% --- Node removed: remove from nodes map ---

project_node_removed(Data, State, RM) ->
    case ets:lookup(?TABLE, ?KEY) of
        [{_, #{nodes := Nodes} = Existing}] ->
            NodeName = gf(node_name, Data),
            NewNodes = maps:remove(NodeName, Nodes),
            Updated = Existing#{nodes => NewNodes},
            {ok, RM2} = evoq_read_model:put(?KEY, Updated, RM),
            {ok, State, RM2};
        [] ->
            {ok, State, RM}
    end.

%% --- Internal ---

get_event_type(#{event_type := T}) -> T;
get_event_type(_) -> undefined.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
