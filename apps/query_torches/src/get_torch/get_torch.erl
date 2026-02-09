%%% @doc Query: get a torch by ID
-module(get_torch).

-export([execute/1]).

%% @doc Get a torch by its ID.
-spec execute(binary()) -> {ok, map()} | {error, not_found | term()}.
execute(TorchId) ->
    Sql = "SELECT torch_id, name, brief, status, repos, skills, context_map, "
          "active_cartwheel_id, initiated_at, initiated_by "
          "FROM torches WHERE torch_id = ?1",
    case query_torches_store:query(Sql, [TorchId]) of
        {ok, [Row]} ->
            {ok, enrich_status(row_to_map(Row))};
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

row_to_map({TorchId, Name, Brief, Status, Repos, Skills, ContextMap,
            ActiveCartwheelId, InitiatedAt, InitiatedBy}) ->
    #{
        torch_id => TorchId,
        name => Name,
        brief => Brief,
        status => Status,
        repos => decode_json(Repos),
        skills => decode_json(Skills),
        context_map => decode_json(ContextMap),
        active_cartwheel_id => ActiveCartwheelId,
        initiated_at => InitiatedAt,
        initiated_by => InitiatedBy
    }.

enrich_status(#{status := Status} = Row) ->
    Label = evoq_bit_flags:to_string(Status, torch_aggregate:flag_map()),
    Row#{status_label => Label}.

-spec decode_json(binary() | undefined) -> term().
decode_json(undefined) -> undefined;
decode_json(null) -> undefined;
decode_json(Bin) when is_binary(Bin) -> json:decode(Bin);
decode_json(_) -> undefined.
