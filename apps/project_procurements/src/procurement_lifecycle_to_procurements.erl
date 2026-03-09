%%% @doc Projection: procurement lifecycle events -> procurements ETS read model.
%%%
%%% Merged projection handling initiated and archived events in a SINGLE
%%% projection to guarantee ordering.
%%% @end
-module(procurement_lifecycle_to_procurements).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-include_lib("guide_procurement_lifecycle/include/procurement_status.hrl").

-define(TABLE, procurements).

interested_in() ->
    [<<"procurement_initiated_v1">>,
     <<"procurement_archived_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = Event, _Metadata, State, RM) ->
    EventType = get_event_type(Event),
    case EventType of
        <<"procurement_initiated_v1">> -> project_initiated(Data, State, RM);
        <<"procurement_archived_v1">>  -> project_archived(Data, State, RM);
        _                              -> {ok, State, RM}
    end.

%% --- Initiated: create procurement entry ---

project_initiated(Data, State, RM) ->
    ProcurementId = gf(procurement_id, Data),
    Entry = #{
        procurement_id => ProcurementId,
        consumer_id    => gf(consumer_id, Data),
        offering_id    => gf(offering_id, Data),
        plugin_id      => gf(plugin_id, Data),
        status         => ?PROC_INITIATED,
        status_label   => <<"Initiated">>,
        initiated_at   => gf(initiated_at, Data),
        archived_at    => undefined
    },
    {ok, RM2} = evoq_read_model:put(ProcurementId, Entry, RM),
    {ok, State, RM2}.

%% --- Archived: update status flag ---

project_archived(Data, State, RM) ->
    ProcurementId = gf(procurement_id, Data),
    case evoq_read_model:get(ProcurementId, RM) of
        {ok, Existing} ->
            Updated = Existing#{
                status       => evoq_bit_flags:set(maps:get(status, Existing), ?PROC_ARCHIVED),
                status_label => <<"Archived">>,
                archived_at  => gf(archived_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(ProcurementId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% --- Internal ---

get_event_type(#{event_type := T}) -> T;
get_event_type(#{<<"event_type">> := T}) -> T;
get_event_type(_) -> undefined.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
