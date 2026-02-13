%%% @doc Query: list active mentor profiles
-module(get_mentors_page).

-export([execute/0, execute/1]).

-spec execute() -> {ok, [map()]} | {error, term()}.
execute() ->
    execute(#{}).

-spec execute(map()) -> {ok, [map()]} | {error, term()}.
execute(Filters) ->
    {Where, Params} = build_where(Filters),
    Sql = "SELECT agent_id, domains, status, declared_at "
          "FROM mentor_profiles WHERE status & 1 != 0" ++ Where,
    case query_mentorships_store:query(Sql, Params) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

build_where(Filters) ->
    case maps:get(domain, Filters, undefined) of
        undefined -> {"", []};
        Domain ->
            %% Search within JSON array of domains
            {" AND domains LIKE ?1", [<<"%\"", Domain/binary, "\"%">>]}
    end.

row_to_map([AgentId, DomainsJson, Status, DeclaredAt]) ->
    Domains = case DomainsJson of
        undefined -> [];
        null -> [];
        Bin when is_binary(Bin) -> json:decode(Bin);
        _ -> []
    end,
    #{
        agent_id => AgentId,
        domains => Domains,
        status => Status,
        declared_at => DeclaredAt
    }.
