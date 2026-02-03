%%% @doc Projection: llm_capability_announced_v1 → capabilities table
%%% Projects LLM capability announcements to the capabilities read model.
%%% LLM capabilities are stored with type = <<"llm">> and rich metadata.
-module(llm_capability_announced_v1_to_capabilities).

-export([project/1]).

%% @doc Project llm_capability_announced_v1 event to capabilities table
-spec project(map()) -> ok | {error, term()}.
project(EventData) when is_map(EventData) ->
    MRI = maps:get(capability_mri, EventData, <<>>),
    AgentID = maps:get(agent_identity, EventData, <<>>),
    ModelName = maps:get(model_name, EventData, <<>>),
    ModelInfo = maps:get(model_info, EventData, #{}),
    HardwareInfo = maps:get(hardware_info, EventData, #{}),
    AnnouncedAt = maps:get(announced_at, EventData, erlang:system_time(millisecond)),

    %% Build tags from model info
    Family = maps:get(family, ModelInfo, <<"unknown">>),
    Tags = [<<"llm">>, Family, ModelName],

    %% Build description
    ParamCount = maps:get(parameter_count, ModelInfo, <<"unknown">>),
    ContextLen = maps:get(context_length, ModelInfo, 4096),
    Description = iolist_to_binary([
        <<"LLM: ">>, ModelName,
        <<" (">>, ensure_binary(ParamCount), <<" params, ">>,
        integer_to_binary(ContextLen), <<" ctx)">>
    ]),

    %% Build metadata with model and hardware info
    Metadata = #{
        type => <<"llm">>,
        model => ModelInfo,
        hardware => HardwareInfo,
        status => #{
            queue_depth => 0,
            avg_tokens_per_sec => 0.0,
            available => true
        }
    },

    %% Serialize to JSON
    TagsJson = json:encode(Tags),
    MetadataJson = json:encode(Metadata),

    %% Insert or replace in SQLite
    Sql = "
        INSERT OR REPLACE INTO capabilities
            (mri, agent_id, tags, description, demo_procedure, metadata, announced_at)
        VALUES
            (?, ?, ?, ?, ?, ?, ?)
    ",
    Params = [MRI, AgentID, TagsJson, Description, null, MetadataJson, AnnouncedAt],

    case query_capabilities_store:execute(Sql, Params) of
        ok ->
            logger:debug("[llm_projection] Projected LLM capability: ~s", [MRI]),
            ok;
        {error, Reason} ->
            logger:warning("[llm_projection] Failed to project: ~p", [Reason]),
            {error, Reason}
    end.

ensure_binary(V) when is_binary(V) -> V;
ensure_binary(V) when is_list(V) -> list_to_binary(V);
ensure_binary(V) when is_integer(V) -> integer_to_binary(V);
ensure_binary(_) -> <<"unknown">>.
