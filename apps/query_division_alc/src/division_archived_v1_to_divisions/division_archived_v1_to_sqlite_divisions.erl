%%% @doc Projection: division_archived_v1 -> divisions table (status update)
-module(division_archived_v1_to_sqlite_divisions).

-include_lib("guide_division_alc/include/division_alc_status.hrl").

-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    logger:info("[PROJECTION] ~s: projecting ~s", [?MODULE, DivisionId]),
    Sql = "UPDATE divisions SET overall_status = overall_status | ?1 "
          "WHERE division_id = ?2",
    query_division_alc_store:execute(Sql, [?DA_ARCHIVED, DivisionId]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
