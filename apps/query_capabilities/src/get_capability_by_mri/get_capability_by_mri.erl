%%% @doc Query: Find capability by MRI
-module(get_capability_by_mri).

-export([execute/1]).

%% Suppress supertype warning (returns specific map, spec uses map())
-dialyzer({nowarn_function, [execute/1]}).

%% @doc Find a capability by its MRI
-spec execute(binary()) -> {ok, map()} | {error, not_found | term()}.
execute(MRI) when is_binary(MRI) ->
    Sql = "
        SELECT mri, agent_id, tags, description, demo_procedure, metadata, announced_at
        FROM capabilities
        WHERE mri = ?
        LIMIT 1
    ",
    case query_capabilities_store:query(Sql, [MRI]) of
        {ok, [[MRI1, AgentID, TagsJson, Desc, DemoProc, MetadataJson, AnnouncedAt]]} ->
            %% Deserialize JSON fields
            Tags = json:decode(TagsJson),
            Metadata = json:decode(MetadataJson),

            Result = #{
                mri => MRI1,
                agent_id => AgentID,
                tags => Tags,
                description => Desc,
                demo_procedure => DemoProc,
                metadata => Metadata,
                announced_at => AnnouncedAt
            },
            {ok, Result};

        {ok, []} ->
            {error, not_found};

        {error, Reason} ->
            {error, Reason}
    end.
