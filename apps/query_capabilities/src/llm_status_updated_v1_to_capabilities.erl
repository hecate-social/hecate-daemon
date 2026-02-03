%%% @doc Projection: llm_status_updated_v1 → capabilities table
%%% Updates LLM capability status (queue depth, availability) in the read model.
-module(llm_status_updated_v1_to_capabilities).

-export([project/1]).

%% @doc Project llm_status_updated_v1 event to capabilities table
-spec project(map()) -> ok | {error, term()}.
project(EventData) when is_map(EventData) ->
    MRI = maps:get(capability_mri, EventData, <<>>),
    QueueDepth = maps:get(queue_depth, EventData, 0),
    AvgTokensPerSec = maps:get(avg_tokens_per_sec, EventData, 0.0),
    Available = maps:get(available, EventData, true),
    UpdatedAt = maps:get(updated_at, EventData, erlang:system_time(millisecond)),

    %% First, get existing metadata
    case get_existing_metadata(MRI) of
        {ok, ExistingMetadata} ->
            %% Update status in metadata
            NewStatus = #{
                queue_depth => QueueDepth,
                avg_tokens_per_sec => AvgTokensPerSec,
                available => Available,
                last_heartbeat => UpdatedAt
            },
            NewMetadata = ExistingMetadata#{status => NewStatus},
            MetadataJson = json:encode(NewMetadata),

            %% Update the record
            Sql = "UPDATE capabilities SET metadata = ? WHERE mri = ?",
            Params = [MetadataJson, MRI],

            case query_capabilities_store:execute(Sql, Params) of
                ok ->
                    logger:debug("[llm_projection] Updated status for: ~s", [MRI]),
                    ok;
                {error, Reason} ->
                    logger:warning("[llm_projection] Failed to update status: ~p", [Reason]),
                    {error, Reason}
            end;

        {error, not_found} ->
            %% Capability doesn't exist yet, skip status update
            logger:debug("[llm_projection] Skipping status update for unknown capability: ~s", [MRI]),
            ok;

        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

get_existing_metadata(MRI) ->
    Sql = "SELECT metadata FROM capabilities WHERE mri = ?",
    case query_capabilities_store:query(Sql, [MRI]) of
        {ok, [[MetadataJson]]} ->
            case json:decode(MetadataJson) of
                Metadata when is_map(Metadata) -> {ok, Metadata};
                _ -> {ok, #{}}
            end;
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.
