%%% @doc Projection: health_check_registered_v1 -> health_checks table
-module(health_check_registered_v1_to_sqlite_health_checks).
-export([project/1]).

project(Event) ->
    CheckId = get(check_id, Event),
    DivisionId = get(division_id, Event),
    CheckName = get(check_name, Event),
    CheckType = get(check_type, Event),
    RegisteredAt = get(registered_at, Event),
    logger:info("[PROJECTION] ~s: projecting ~s/~s", [?MODULE, DivisionId, CheckId]),
    Sql = "INSERT OR REPLACE INTO health_checks "
          "(check_id, division_id, check_name, check_type, "
          "last_status, last_checked_at, registered_at) "
          "VALUES (?1, ?2, ?3, ?4, NULL, NULL, ?5)",
    query_division_alc_store:execute(Sql, [CheckId, DivisionId, CheckName,
                                           CheckType, RegisteredAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
