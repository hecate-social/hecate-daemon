%%% @doc Query: list active capabilities with pagination.
-module(get_capabilities_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    Limit = maps:get(limit, Filters, 100),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT mri, agent_id, tags, description, demo_procedure, "
          "metadata, announced_at, updated_at, retracted_at "
          "FROM capabilities "
          "WHERE retracted_at IS NULL "
          "ORDER BY announced_at DESC "
          "LIMIT ?1 OFFSET ?2",
    case query_node_lifecycle_store:query(Sql, [Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({Mri, AgentId, Tags, Description, DemoProcedure,
            Metadata, AnnouncedAt, UpdatedAt, _RetractedAt}) ->
    #{
        mri => Mri,
        agent_id => AgentId,
        tags => decode_json(Tags),
        description => Description,
        demo_procedure => DemoProcedure,
        metadata => decode_json(Metadata),
        announced_at => AnnouncedAt,
        updated_at => UpdatedAt
    };
row_to_map(Row) when is_list(Row) ->
    row_to_map(list_to_tuple(Row)).

decode_json(null) -> null;
decode_json(undefined) -> null;
decode_json(Val) when is_binary(Val) -> json:decode(Val);
decode_json(Val) -> Val.
