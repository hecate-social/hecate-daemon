-module(apply_fix_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_fix_id/1, get_incident_id/1, get_description/1]).
-export([generate_id/0]).
-record(apply_fix_v1, {division_id :: binary(), fix_id :: binary(), incident_id :: binary(), description :: binary() | undefined}).
-export_type([apply_fix_v1/0]).
-opaque apply_fix_v1() :: #apply_fix_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).
new(#{division_id := DI, incident_id := II} = P) -> {ok, #apply_fix_v1{division_id = DI, fix_id = maps:get(fix_id, P, generate_id()), incident_id = II, description = maps:get(description, P, undefined)}};
new(_) -> {error, missing_required_fields}.
validate(#apply_fix_v1{division_id = V}) when not is_binary(V); byte_size(V) =:= 0 -> {error, invalid_division_id};
validate(#apply_fix_v1{incident_id = V}) when not is_binary(V); byte_size(V) =:= 0 -> {error, invalid_incident_id};
validate(#apply_fix_v1{} = C) -> {ok, C}.
to_map(#apply_fix_v1{} = C) -> #{<<"command_type">> => <<"apply_fix">>, <<"division_id">> => C#apply_fix_v1.division_id, <<"fix_id">> => C#apply_fix_v1.fix_id, <<"incident_id">> => C#apply_fix_v1.incident_id, <<"description">> => C#apply_fix_v1.description}.
from_map(Map) -> DI = gv(division_id, Map), II = gv(incident_id, Map),
    case {DI, II} of {undefined,_} -> {error, missing_required_fields}; {_,undefined} -> {error, missing_required_fields};
        _ -> {ok, #apply_fix_v1{division_id = DI, fix_id = gv(fix_id, Map, generate_id()), incident_id = II, description = gv(description, Map, undefined)}} end.
get_division_id(#apply_fix_v1{division_id = V}) -> V.
get_fix_id(#apply_fix_v1{fix_id = V}) -> V.
get_incident_id(#apply_fix_v1{incident_id = V}) -> V.
get_description(#apply_fix_v1{description = V}) -> V.
generate_id() -> Ts = integer_to_binary(erlang:system_time(millisecond)), Rand = binary:encode_hex(crypto:strong_rand_bytes(4)), <<"fix-", Ts/binary, "-", Rand/binary>>.
gv(Key, Map) -> gv(Key, Map, undefined).
gv(Key, Map, Default) when is_atom(Key) -> BK = atom_to_binary(Key, utf8), case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BK, Map) of {ok, V} -> V; error -> Default end end.
