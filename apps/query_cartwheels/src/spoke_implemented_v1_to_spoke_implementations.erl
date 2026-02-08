%%% @doc Projection: spoke_implemented_v1 -> spoke_implementations table + cartwheels counter
-module(spoke_implemented_v1_to_spoke_implementations).

-export([project/1]).

%% @doc Project spoke_implemented_v1 event to spoke_implementations table and increment project counter
-spec project(map()) -> ok | {error, term()}.
project(#{implementation_id := ImplId, cartwheel_id := PId, spoke_id := SId} = E) ->
    InsertSql = "INSERT OR REPLACE INTO spoke_implementations "
                "(implementation_id, cartwheel_id, spoke_id, implementation_notes, implemented_at) "
                "VALUES (?1, ?2, ?3, ?4, ?5)",
    ok = query_cartwheels_store:execute(InsertSql, [
        ImplId,
        PId,
        SId,
        maps:get(implementation_notes, E, undefined),
        maps:get(implemented_at, E, erlang:system_time(millisecond))
    ]),
    CountSql = "UPDATE cartwheels SET implemented_spoke_count = implemented_spoke_count + 1 "
               "WHERE cartwheel_id = ?1",
    query_cartwheels_store:execute(CountSql, [PId]).
