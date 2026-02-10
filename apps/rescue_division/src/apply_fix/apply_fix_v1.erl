-module(apply_fix_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_incident_id/1, get_diagnosis_id/1,
         get_fix_description/1, get_fix_type/1, get_applied_by/1]).

-record(apply_fix_v1, {
    division_id :: binary(),
    incident_id :: binary(),
    diagnosis_id :: binary(),
    fix_description :: binary(),
    fix_type :: binary(),
    applied_by :: binary() | undefined
}).

new(#{division_id := DivisionId, incident_id := IncidentId,
      diagnosis_id := DiagnosisId, fix_description := FixDescription,
      fix_type := FixType} = Params) ->
    Cmd = #apply_fix_v1{
        division_id = DivisionId,
        incident_id = IncidentId,
        diagnosis_id = DiagnosisId,
        fix_description = FixDescription,
        fix_type = FixType,
        applied_by = maps:get(applied_by, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#apply_fix_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#apply_fix_v1{incident_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, incident_id}};
validate(#apply_fix_v1{diagnosis_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, diagnosis_id}};
validate(#apply_fix_v1{fix_description = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, fix_description}};
validate(#apply_fix_v1{fix_type = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, fix_type}};
validate(_) -> ok.

to_map(#apply_fix_v1{division_id = DI, incident_id = II,
                      diagnosis_id = DgId, fix_description = FD,
                      fix_type = FT, applied_by = AB}) ->
    #{
        <<"command_type">> => <<"apply_fix">>,
        <<"division_id">> => DI,
        <<"incident_id">> => II,
        <<"diagnosis_id">> => DgId,
        <<"fix_description">> => FD,
        <<"fix_type">> => FT,
        <<"applied_by">> => AB
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    IncidentId = get_val(incident_id, Map),
    DiagnosisId = get_val(diagnosis_id, Map),
    FixDescription = get_val(fix_description, Map),
    FixType = get_val(fix_type, Map),
    AppliedBy = get_val(applied_by, Map),
    new(#{division_id => DivisionId, incident_id => IncidentId,
          diagnosis_id => DiagnosisId, fix_description => FixDescription,
          fix_type => FixType, applied_by => AppliedBy}).

get_division_id(#apply_fix_v1{division_id = V}) -> V.
get_incident_id(#apply_fix_v1{incident_id = V}) -> V.
get_diagnosis_id(#apply_fix_v1{diagnosis_id = V}) -> V.
get_fix_description(#apply_fix_v1{fix_description = V}) -> V.
get_fix_type(#apply_fix_v1{fix_type = V}) -> V.
get_applied_by(#apply_fix_v1{applied_by = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
