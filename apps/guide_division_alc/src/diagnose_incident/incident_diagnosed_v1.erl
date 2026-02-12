-module(incident_diagnosed_v1).
-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_diagnosis_id/1, get_incident_id/1, get_root_cause/1, get_diagnosed_at/1]).
-record(incident_diagnosed_v1, {division_id :: binary(), diagnosis_id :: binary(), incident_id :: binary(), root_cause :: binary() | undefined, diagnosed_at :: integer()}).
-export_type([incident_diagnosed_v1/0]).
-opaque incident_diagnosed_v1() :: #incident_diagnosed_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).
new(#{division_id := DI, diagnosis_id := DgI, incident_id := II} = P) -> #incident_diagnosed_v1{division_id = DI, diagnosis_id = DgI, incident_id = II, root_cause = maps:get(root_cause, P, undefined), diagnosed_at = erlang:system_time(millisecond)}.
to_map(#incident_diagnosed_v1{} = E) -> #{<<"event_type">> => <<"incident_diagnosed_v1">>, <<"division_id">> => E#incident_diagnosed_v1.division_id, <<"diagnosis_id">> => E#incident_diagnosed_v1.diagnosis_id, <<"incident_id">> => E#incident_diagnosed_v1.incident_id, <<"root_cause">> => E#incident_diagnosed_v1.root_cause, <<"diagnosed_at">> => E#incident_diagnosed_v1.diagnosed_at}.
from_map(Map) -> DI = gv(division_id, Map), DgI = gv(diagnosis_id, Map),
    case {DI, DgI} of {undefined,_} -> {error, invalid_event}; {_,undefined} -> {error, invalid_event};
        _ -> {ok, #incident_diagnosed_v1{division_id = DI, diagnosis_id = DgI, incident_id = gv(incident_id, Map, <<>>), root_cause = gv(root_cause, Map, undefined), diagnosed_at = gv(diagnosed_at, Map, erlang:system_time(millisecond))}} end.
get_division_id(#incident_diagnosed_v1{division_id = V}) -> V.
get_diagnosis_id(#incident_diagnosed_v1{diagnosis_id = V}) -> V.
get_incident_id(#incident_diagnosed_v1{incident_id = V}) -> V.
get_root_cause(#incident_diagnosed_v1{root_cause = V}) -> V.
get_diagnosed_at(#incident_diagnosed_v1{diagnosed_at = V}) -> V.
gv(Key, Map) -> gv(Key, Map, undefined).
gv(Key, Map, Default) when is_atom(Key) -> BK = atom_to_binary(Key, utf8), case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BK, Map) of {ok, V} -> V; error -> Default end end.
