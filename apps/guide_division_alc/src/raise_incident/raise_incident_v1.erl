-module(raise_incident_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_incident_id/1, get_title/1, get_severity/1]).
-export([generate_id/0]).
-record(raise_incident_v1, {division_id :: binary(), incident_id :: binary(), title :: binary(), severity :: binary() | undefined}).
-export_type([raise_incident_v1/0]).
-opaque raise_incident_v1() :: #raise_incident_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).
new(#{division_id := DI, title := T} = P) -> {ok, #raise_incident_v1{division_id = DI, incident_id = maps:get(incident_id, P, generate_id()), title = T, severity = maps:get(severity, P, undefined)}};
new(_) -> {error, missing_required_fields}.
validate(#raise_incident_v1{division_id = V}) when not is_binary(V); byte_size(V) =:= 0 -> {error, invalid_division_id};
validate(#raise_incident_v1{title = T}) when not is_binary(T); byte_size(T) =:= 0 -> {error, invalid_title};
validate(#raise_incident_v1{} = C) -> {ok, C}.
to_map(#raise_incident_v1{} = C) -> #{<<"command_type">> => <<"raise_incident">>, <<"division_id">> => C#raise_incident_v1.division_id, <<"incident_id">> => C#raise_incident_v1.incident_id, <<"title">> => C#raise_incident_v1.title, <<"severity">> => C#raise_incident_v1.severity}.
from_map(Map) -> DI = gv(division_id, Map), T = gv(title, Map),
    case {DI, T} of {undefined,_} -> {error, missing_required_fields}; {_,undefined} -> {error, missing_required_fields};
        _ -> {ok, #raise_incident_v1{division_id = DI, incident_id = gv(incident_id, Map, generate_id()), title = T, severity = gv(severity, Map, undefined)}} end.
get_division_id(#raise_incident_v1{division_id = V}) -> V.
get_incident_id(#raise_incident_v1{incident_id = V}) -> V.
get_title(#raise_incident_v1{title = V}) -> V.
get_severity(#raise_incident_v1{severity = V}) -> V.
generate_id() -> Ts = integer_to_binary(erlang:system_time(millisecond)), Rand = binary:encode_hex(crypto:strong_rand_bytes(4)), <<"incident-", Ts/binary, "-", Rand/binary>>.
gv(Key, Map) -> gv(Key, Map, undefined).
gv(Key, Map, Default) when is_atom(Key) -> BK = atom_to_binary(Key, utf8), case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BK, Map) of {ok, V} -> V; error -> Default end end.
