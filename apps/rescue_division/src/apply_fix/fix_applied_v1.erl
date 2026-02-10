-module(fix_applied_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_division_id/1, get_fix_id/1, get_incident_id/1,
         get_diagnosis_id/1, get_fix_description/1, get_fix_type/1,
         get_applied_by/1, get_applied_at/1]).

-record(fix_applied_v1, {
    division_id :: binary(),
    fix_id :: binary(),
    incident_id :: binary(),
    diagnosis_id :: binary(),
    fix_description :: binary(),
    fix_type :: binary(),
    applied_by :: binary() | undefined,
    applied_at :: non_neg_integer()
}).

new(#{division_id := DivisionId, incident_id := IncidentId,
      diagnosis_id := DiagnosisId, fix_description := FixDescription,
      fix_type := FixType} = Params) ->
    Timestamp = erlang:system_time(millisecond),
    FixId = maps:get(fix_id, Params,
        <<"fix-", IncidentId/binary, "-", (integer_to_binary(Timestamp))/binary>>),
    #fix_applied_v1{
        division_id = DivisionId,
        fix_id = FixId,
        incident_id = IncidentId,
        diagnosis_id = DiagnosisId,
        fix_description = FixDescription,
        fix_type = FixType,
        applied_by = maps:get(applied_by, Params, undefined),
        applied_at = maps:get(applied_at, Params, Timestamp)
    }.

to_map(#fix_applied_v1{division_id = DI, fix_id = FId,
                        incident_id = II, diagnosis_id = DgId,
                        fix_description = FD, fix_type = FT,
                        applied_by = AB, applied_at = AA}) ->
    #{
        <<"event_type">> => <<"fix_applied_v1">>,
        <<"division_id">> => DI,
        <<"fix_id">> => FId,
        <<"incident_id">> => II,
        <<"diagnosis_id">> => DgId,
        <<"fix_description">> => FD,
        <<"fix_type">> => FT,
        <<"applied_by">> => AB,
        <<"applied_at">> => AA
    }.

from_map(Map) ->
    {ok, #fix_applied_v1{
        division_id = get_val(division_id, Map),
        fix_id = get_val(fix_id, Map),
        incident_id = get_val(incident_id, Map),
        diagnosis_id = get_val(diagnosis_id, Map),
        fix_description = get_val(fix_description, Map),
        fix_type = get_val(fix_type, Map),
        applied_by = get_val(applied_by, Map),
        applied_at = get_val(applied_at, Map)
    }}.

get_division_id(#fix_applied_v1{division_id = V}) -> V.
get_fix_id(#fix_applied_v1{fix_id = V}) -> V.
get_incident_id(#fix_applied_v1{incident_id = V}) -> V.
get_diagnosis_id(#fix_applied_v1{diagnosis_id = V}) -> V.
get_fix_description(#fix_applied_v1{fix_description = V}) -> V.
get_fix_type(#fix_applied_v1{fix_type = V}) -> V.
get_applied_by(#fix_applied_v1{applied_by = V}) -> V.
get_applied_at(#fix_applied_v1{applied_at = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
