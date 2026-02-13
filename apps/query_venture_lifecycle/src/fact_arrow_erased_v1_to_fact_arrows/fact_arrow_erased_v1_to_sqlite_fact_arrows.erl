%%% @doc Projection: fact_arrow_erased_v1 -> fact_arrows table
-module(fact_arrow_erased_v1_to_sqlite_fact_arrows).
-export([project/1]).

project(Event) ->
    ArrowId = get(arrow_id, Event),
    logger:info("[PROJECTION] ~s: erasing arrow ~s", [?MODULE, ArrowId]),
    Sql = "DELETE FROM fact_arrows WHERE arrow_id = ?1",
    query_venture_lifecycle_store:execute(Sql, [ArrowId]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
