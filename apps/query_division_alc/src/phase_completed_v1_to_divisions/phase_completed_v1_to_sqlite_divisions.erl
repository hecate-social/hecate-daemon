%%% @doc Projection: phase_completed_v1 -> divisions table (phase status update)
%%% Updates the appropriate phase column (dna_status, anp_status, etc.) based
%%% on the "phase" field in the event.
-module(phase_completed_v1_to_sqlite_divisions).

-include_lib("guide_division_alc/include/division_alc_status.hrl").

-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    Phase = get(phase, Event),
    Column = phase_to_column(Phase),
    logger:info("[PROJECTION] ~s: projecting ~s phase=~s", [?MODULE, DivisionId, Phase]),
    Sql = iolist_to_binary([
        "UPDATE divisions SET ", Column, " = ?1 WHERE division_id = ?2"
    ]),
    query_division_alc_store:execute(Sql, [?PHASE_COMPLETED, DivisionId]).

phase_to_column(<<"dna">>) -> <<"dna_status">>;
phase_to_column(<<"anp">>) -> <<"anp_status">>;
phase_to_column(<<"tni">>) -> <<"tni_status">>;
phase_to_column(<<"dno">>) -> <<"dno_status">>;
phase_to_column(Phase) when is_atom(Phase) ->
    phase_to_column(atom_to_binary(Phase)).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
