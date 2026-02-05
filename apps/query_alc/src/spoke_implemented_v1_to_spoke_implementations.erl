%%% @doc Projection: spoke_implemented_v1 -> spoke_implementations table + projects counter
-module(spoke_implemented_v1_to_spoke_implementations).

-export([project/1]).

%% @doc Project spoke_implemented_v1 event to spoke_implementations table and increment project counter
-spec project(map()) -> ok | {error, term()}.
project(#{implementation_id := ImplId, project_id := PId, spoke_id := SId} = E) ->
    InsertSql = "INSERT OR REPLACE INTO spoke_implementations "
                "(implementation_id, project_id, spoke_id, implementation_notes, implemented_at) "
                "VALUES (?1, ?2, ?3, ?4, ?5)",
    ok = query_alc_store:execute(InsertSql, [
        ImplId,
        PId,
        SId,
        maps:get(implementation_notes, E, undefined),
        maps:get(implemented_at, E, erlang:system_time(millisecond))
    ]),
    CountSql = "UPDATE projects SET implemented_spoke_count = implemented_spoke_count + 1 "
               "WHERE project_id = ?1",
    query_alc_store:execute(CountSql, [PId]).
