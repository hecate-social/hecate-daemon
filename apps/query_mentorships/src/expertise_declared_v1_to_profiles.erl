%%% @doc Projection: expertise_declared_v1 -> mentor_profiles table (UPSERT)
-module(expertise_declared_v1_to_profiles).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{agent_id := AId, domains := Domains} = E) ->
    DomainsJson = iolist_to_binary(json:encode(Domains)),
    DeclaredAt = maps:get(declared_at, E, erlang:system_time(millisecond)),
    Sql = "INSERT OR REPLACE INTO mentor_profiles "
          "(agent_id, domains, status, declared_at) "
          "VALUES (?1, ?2, 1, ?3)",
    query_mentorships_store:execute(Sql, [AId, DomainsJson, DeclaredAt]).
