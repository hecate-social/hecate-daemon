%%% @doc Query: find a capability by its MRI.
-module(get_capability_by_mri).
-export([get/1]).

-spec get(binary()) -> {ok, map()} | {error, not_found | term()}.
get(Mri) ->
    Sql = "SELECT mri, agent_id, tags, description, demo_procedure, "
          "metadata, announced_at, updated_at, retracted_at "
          "FROM capabilities WHERE mri = ?1",
    case query_node_lifecycle_store:query(Sql, [Mri]) of
        {ok, [Row]} ->
            {ok, row_to_map(Row)};
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({Mri, AgentId, Tags, Description, DemoProcedure,
            Metadata, AnnouncedAt, UpdatedAt, RetractedAt}) ->
    #{
        mri => Mri,
        agent_id => AgentId,
        tags => decode_json(Tags),
        description => Description,
        demo_procedure => DemoProcedure,
        metadata => decode_json(Metadata),
        announced_at => AnnouncedAt,
        updated_at => UpdatedAt,
        retracted_at => RetractedAt
    };
row_to_map(Row) when is_list(Row) ->
    row_to_map(list_to_tuple(Row)).

decode_json(null) -> null;
decode_json(undefined) -> null;
decode_json(Val) when is_binary(Val) -> json:decode(Val);
decode_json(Val) -> Val.
