-module(incident_diagnosed_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_division_id/1, get_diagnosis_id/1, get_incident_id/1,
         get_diagnosis/1, get_root_cause/1, get_diagnosed_by/1,
         get_diagnosed_at/1]).

-record(incident_diagnosed_v1, {
    division_id :: binary(),
    diagnosis_id :: binary(),
    incident_id :: binary(),
    diagnosis :: binary(),
    root_cause :: binary(),
    diagnosed_by :: binary() | undefined,
    diagnosed_at :: non_neg_integer()
}).

new(#{division_id := DivisionId, incident_id := IncidentId,
      diagnosis := Diagnosis, root_cause := RootCause} = Params) ->
    Timestamp = erlang:system_time(millisecond),
    DiagnosisId = maps:get(diagnosis_id, Params,
        <<"diag-", IncidentId/binary, "-", (integer_to_binary(Timestamp))/binary>>),
    #incident_diagnosed_v1{
        division_id = DivisionId,
        diagnosis_id = DiagnosisId,
        incident_id = IncidentId,
        diagnosis = Diagnosis,
        root_cause = RootCause,
        diagnosed_by = maps:get(diagnosed_by, Params, undefined),
        diagnosed_at = maps:get(diagnosed_at, Params, Timestamp)
    }.

to_map(#incident_diagnosed_v1{division_id = DI, diagnosis_id = DgId,
                               incident_id = II, diagnosis = D,
                               root_cause = RC, diagnosed_by = DB,
                               diagnosed_at = DA}) ->
    #{
        <<"event_type">> => <<"incident_diagnosed_v1">>,
        <<"division_id">> => DI,
        <<"diagnosis_id">> => DgId,
        <<"incident_id">> => II,
        <<"diagnosis">> => D,
        <<"root_cause">> => RC,
        <<"diagnosed_by">> => DB,
        <<"diagnosed_at">> => DA
    }.

from_map(Map) ->
    {ok, #incident_diagnosed_v1{
        division_id = get_val(division_id, Map),
        diagnosis_id = get_val(diagnosis_id, Map),
        incident_id = get_val(incident_id, Map),
        diagnosis = get_val(diagnosis, Map),
        root_cause = get_val(root_cause, Map),
        diagnosed_by = get_val(diagnosed_by, Map),
        diagnosed_at = get_val(diagnosed_at, Map)
    }}.

get_division_id(#incident_diagnosed_v1{division_id = V}) -> V.
get_diagnosis_id(#incident_diagnosed_v1{diagnosis_id = V}) -> V.
get_incident_id(#incident_diagnosed_v1{incident_id = V}) -> V.
get_diagnosis(#incident_diagnosed_v1{diagnosis = V}) -> V.
get_root_cause(#incident_diagnosed_v1{root_cause = V}) -> V.
get_diagnosed_by(#incident_diagnosed_v1{diagnosed_by = V}) -> V.
get_diagnosed_at(#incident_diagnosed_v1{diagnosed_at = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
