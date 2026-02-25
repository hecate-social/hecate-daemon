%%% @doc Query: get a mentor profile by agent_id
-module(get_mentor_profile_by_id).

-export([execute/1]).

-spec execute(binary()) -> {ok, map()} | {error, not_found | term()}.
execute(AgentId) ->
    Sql = "SELECT agent_id, domains, status, declared_at "
          "FROM mentor_profiles WHERE agent_id = ?1",
    case project_llm_mentorships_store:query(Sql, [AgentId]) of
        {ok, [Row]} ->
            {ok, row_to_map(Row)};
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

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
