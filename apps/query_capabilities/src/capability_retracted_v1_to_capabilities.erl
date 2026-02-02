%%% @doc Projection: capability_retracted_v1 → capabilities table
%%% Marks capabilities as retracted in SQLite read model.
-module(capability_retracted_v1_to_capabilities).

-export([project/1, project/2]).

%% @doc Project capability_retracted_v1 event to capabilities table (from map)
-spec project(map()) -> ok | {error, term()}.
project(EventData) when is_map(EventData) ->
    MRI = maps:get(capability_mri, EventData),
    RetractedAt = maps:get(retracted_at, EventData, erlang:system_time(millisecond)),

    do_project(MRI, RetractedAt).

%% @doc Project capability_retracted_v1 event to capabilities table (from record)
-spec project(capability_retracted_v1:capability_retracted_v1(), map()) -> ok | {error, term()}.
project(Event, _Metadata) ->
    MRI = capability_retracted_v1:get_mri(Event),
    RetractedAt = capability_retracted_v1:get_retracted_at(Event),

    do_project(MRI, RetractedAt).

%% Internal projection logic
do_project(MRI, RetractedAt) ->
    Sql = "UPDATE capabilities SET retracted_at = ? WHERE mri = ?",
    Params = [RetractedAt, MRI],

    case query_capabilities_store:execute(Sql, Params) of
        ok -> ok;
        {error, Reason} ->
            io:format("Failed to project capability_retracted_v1: ~p~n", [Reason]),
            {error, Reason}
    end.
