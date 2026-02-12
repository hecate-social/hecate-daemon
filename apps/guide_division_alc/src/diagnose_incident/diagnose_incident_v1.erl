-module(diagnose_incident_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_diagnosis_id/1, get_incident_id/1, get_root_cause/1]).
-export([generate_id/0]).
-record(diagnose_incident_v1, {division_id :: binary(), diagnosis_id :: binary(), incident_id :: binary(), root_cause :: binary() | undefined}).
-export_type([diagnose_incident_v1/0]).
-opaque diagnose_incident_v1() :: #diagnose_incident_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).
new(#{division_id := DI, incident_id := II} = P) -> {ok, #diagnose_incident_v1{division_id = DI, diagnosis_id = maps:get(diagnosis_id, P, generate_id()), incident_id = II, root_cause = maps:get(root_cause, P, undefined)}};
new(_) -> {error, missing_required_fields}.
validate(#diagnose_incident_v1{division_id = V}) when not is_binary(V); byte_size(V) =:= 0 -> {error, invalid_division_id};
validate(#diagnose_incident_v1{incident_id = V}) when not is_binary(V); byte_size(V) =:= 0 -> {error, invalid_incident_id};
validate(#diagnose_incident_v1{} = C) -> {ok, C}.
to_map(#diagnose_incident_v1{} = C) -> #{<<"command_type">> => <<"diagnose_incident">>, <<"division_id">> => C#diagnose_incident_v1.division_id, <<"diagnosis_id">> => C#diagnose_incident_v1.diagnosis_id, <<"incident_id">> => C#diagnose_incident_v1.incident_id, <<"root_cause">> => C#diagnose_incident_v1.root_cause}.
from_map(Map) -> DI = gv(division_id, Map), II = gv(incident_id, Map),
    case {DI, II} of {undefined,_} -> {error, missing_required_fields}; {_,undefined} -> {error, missing_required_fields};
        _ -> {ok, #diagnose_incident_v1{division_id = DI, diagnosis_id = gv(diagnosis_id, Map, generate_id()), incident_id = II, root_cause = gv(root_cause, Map, undefined)}} end.
get_division_id(#diagnose_incident_v1{division_id = V}) -> V.
get_diagnosis_id(#diagnose_incident_v1{diagnosis_id = V}) -> V.
get_incident_id(#diagnose_incident_v1{incident_id = V}) -> V.
get_root_cause(#diagnose_incident_v1{root_cause = V}) -> V.
generate_id() -> Ts = integer_to_binary(erlang:system_time(millisecond)), Rand = binary:encode_hex(crypto:strong_rand_bytes(4)), <<"diagnosis-", Ts/binary, "-", Rand/binary>>.
gv(Key, Map) -> gv(Key, Map, undefined).
gv(Key, Map, Default) when is_atom(Key) -> BK = atom_to_binary(Key, utf8), case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BK, Map) of {ok, V} -> V; error -> Default end end.
