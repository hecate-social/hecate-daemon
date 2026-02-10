-module(diagnose_incident_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_incident_id/1, get_diagnosis/1,
         get_root_cause/1, get_diagnosed_by/1]).

-record(diagnose_incident_v1, {
    division_id :: binary(),
    incident_id :: binary(),
    diagnosis :: binary(),
    root_cause :: binary(),
    diagnosed_by :: binary() | undefined
}).

new(#{division_id := DivisionId, incident_id := IncidentId,
      diagnosis := Diagnosis, root_cause := RootCause} = Params) ->
    Cmd = #diagnose_incident_v1{
        division_id = DivisionId,
        incident_id = IncidentId,
        diagnosis = Diagnosis,
        root_cause = RootCause,
        diagnosed_by = maps:get(diagnosed_by, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#diagnose_incident_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#diagnose_incident_v1{incident_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, incident_id}};
validate(#diagnose_incident_v1{diagnosis = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, diagnosis}};
validate(#diagnose_incident_v1{root_cause = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, root_cause}};
validate(_) -> ok.

to_map(#diagnose_incident_v1{division_id = DI, incident_id = II,
                              diagnosis = D, root_cause = RC,
                              diagnosed_by = DB}) ->
    #{
        <<"command_type">> => <<"diagnose_incident">>,
        <<"division_id">> => DI,
        <<"incident_id">> => II,
        <<"diagnosis">> => D,
        <<"root_cause">> => RC,
        <<"diagnosed_by">> => DB
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    IncidentId = get_val(incident_id, Map),
    Diagnosis = get_val(diagnosis, Map),
    RootCause = get_val(root_cause, Map),
    DiagnosedBy = get_val(diagnosed_by, Map),
    new(#{division_id => DivisionId, incident_id => IncidentId,
          diagnosis => Diagnosis, root_cause => RootCause,
          diagnosed_by => DiagnosedBy}).

get_division_id(#diagnose_incident_v1{division_id = V}) -> V.
get_incident_id(#diagnose_incident_v1{incident_id = V}) -> V.
get_diagnosis(#diagnose_incident_v1{diagnosis = V}) -> V.
get_root_cause(#diagnose_incident_v1{root_cause = V}) -> V.
get_diagnosed_by(#diagnose_incident_v1{diagnosed_by = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
