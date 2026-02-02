%%% @doc Projection: capability_updated_v1 → capabilities table
%%% Updates SQLite read model when capabilities are updated.
-module(capability_updated_v1_to_capabilities).

-export([project/1, project/2]).

%% @doc Project capability_updated_v1 event to capabilities table (from map)
%% Only updates fields that were provided in the event (non-undefined)
-spec project(map()) -> ok | {error, term()}.
project(EventData) when is_map(EventData) ->
    MRI = maps:get(capability_mri, EventData),
    Tags = maps:get(tags, EventData, undefined),
    Desc = maps:get(description, EventData, undefined),
    DemoProc = maps:get(demo_procedure, EventData, undefined),
    Metadata = maps:get(metadata, EventData, undefined),
    UpdatedAt = maps:get(updated_at, EventData, erlang:system_time(millisecond)),

    do_project(MRI, Tags, Desc, DemoProc, Metadata, UpdatedAt).

%% @doc Project capability_updated_v1 event to capabilities table (from record)
-spec project(capability_updated_v1:capability_updated_v1(), map()) -> ok | {error, term()}.
project(Event, _Metadata) ->
    MRI = capability_updated_v1:get_mri(Event),
    Tags = capability_updated_v1:get_tags(Event),
    Desc = capability_updated_v1:get_description(Event),
    DemoProc = capability_updated_v1:get_demo_procedure(Event),
    Metadata = capability_updated_v1:get_metadata(Event),
    UpdatedAt = capability_updated_v1:get_updated_at(Event),

    do_project(MRI, Tags, Desc, DemoProc, Metadata, UpdatedAt).

%% Internal projection logic - builds dynamic UPDATE statement
do_project(MRI, Tags, Desc, DemoProc, Metadata, UpdatedAt) ->
    %% Build SET clauses for non-undefined fields
    {SetClauses, Params} = build_set_clauses([
        {<<"tags">>, Tags, fun json:encode/1},
        {<<"description">>, Desc, fun(X) -> X end},
        {<<"demo_procedure">>, DemoProc, fun(X) -> X end},
        {<<"metadata">>, Metadata, fun json:encode/1}
    ]),

    %% Always update updated_at
    AllSetClauses = SetClauses ++ [<<"updated_at = ?">>],
    AllParams = Params ++ [UpdatedAt, MRI],

    Sql = iolist_to_binary([
        "UPDATE capabilities SET ",
        lists:join(<<", ">>, AllSetClauses),
        " WHERE mri = ?"
    ]),

    case query_capabilities_store:execute(binary_to_list(Sql), AllParams) of
        ok -> ok;
        {error, Reason} ->
            io:format("Failed to project capability_updated_v1: ~p~n", [Reason]),
            {error, Reason}
    end.

%% Build SET clauses from field list, skipping undefined values
build_set_clauses(Fields) ->
    build_set_clauses(Fields, [], []).

build_set_clauses([], Clauses, Params) ->
    {lists:reverse(Clauses), lists:reverse(Params)};
build_set_clauses([{_Name, undefined, _Encoder} | Rest], Clauses, Params) ->
    build_set_clauses(Rest, Clauses, Params);
build_set_clauses([{Name, Value, Encoder} | Rest], Clauses, Params) ->
    Clause = <<Name/binary, " = ?">>,
    EncodedValue = Encoder(Value),
    build_set_clauses(Rest, [Clause | Clauses], [EncodedValue | Params]).
