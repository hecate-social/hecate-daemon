%%% @doc Projection: capability_announced_v1 → capabilities table
%%% Subscribes to capability_announced_v1 events and updates SQLite read model.
-module(capability_announced_v1_to_capabilities).

-export([project/1, project/2]).

%% @doc Project capability_announced_v1 event to capabilities table (from map)
%% @param EventData Event data as map (from subscription or integration test)
-spec project(map()) -> ok | {error, term()}.
project(EventData) when is_map(EventData) ->
    %% Extract fields directly from map
    MRI = maps:get(capability_mri, EventData),
    AgentID = maps:get(agent_identity, EventData),
    Tags = maps:get(tags, EventData),
    Desc = maps:get(description, EventData),
    DemoProc = maps:get(demo_procedure, EventData, undefined),
    Metadata = maps:get(metadata, EventData, #{}),
    AnnouncedAt = maps:get(announced_at, Metadata, erlang:system_time(millisecond)),

    do_project(MRI, AgentID, Tags, Desc, DemoProc, Metadata, AnnouncedAt).

%% @doc Project capability_announced_v1 event to capabilities table (from record)
%% @param Event Business event record
%% @param Metadata Event metadata (from evoq_event.metadata field)
-spec project(capability_announced_v1:capability_announced_v1(), map()) -> ok | {error, term()}.
project(Event, _Metadata) ->
    %% Extract fields from event using accessors from command service
    MRI = capability_announced_v1:get_mri(Event),
    AgentID = capability_announced_v1:get_agent_id(Event),
    Tags = capability_announced_v1:get_tags(Event),
    Desc = capability_announced_v1:get_description(Event),
    DemoProc = capability_announced_v1:get_demo_procedure(Event),
    Metadata = capability_announced_v1:get_metadata(Event),
    AnnouncedAt = capability_announced_v1:get_announced_at(Event),

    do_project(MRI, AgentID, Tags, Desc, DemoProc, Metadata, AnnouncedAt).

%% Internal projection logic
do_project(MRI, AgentID, Tags, Desc, DemoProc, Metadata, AnnouncedAt) ->

    %% Serialize lists and maps to JSON
    TagsJson = json:encode(Tags),
    MetadataJson = json:encode(Metadata),
    DemoProcBin = case DemoProc of
        undefined -> null;
        Bin -> Bin
    end,

    %% Insert or replace in SQLite
    Sql = "
        INSERT OR REPLACE INTO capabilities
            (mri, agent_id, tags, description, demo_procedure, metadata, announced_at)
        VALUES
            (?, ?, ?, ?, ?, ?, ?)
    ",
    Params = [MRI, AgentID, TagsJson, Desc, DemoProcBin, MetadataJson, AnnouncedAt],

    case query_capabilities_store:execute(Sql, Params) of
        ok -> ok;
        {error, Reason} ->
            io:format("Failed to project capability_announced_v1: ~p~n", [Reason]),
            {error, Reason}
    end.
