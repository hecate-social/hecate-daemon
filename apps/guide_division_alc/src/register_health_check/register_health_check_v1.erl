-module(register_health_check_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_check_id/1, get_check_name/1, get_check_type/1]).
-export([generate_id/0]).
-record(register_health_check_v1, {division_id :: binary(), check_id :: binary(), check_name :: binary(), check_type :: binary() | undefined}).
-export_type([register_health_check_v1/0]).
-opaque register_health_check_v1() :: #register_health_check_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).
new(#{division_id := DI, check_name := CN} = P) -> {ok, #register_health_check_v1{division_id = DI, check_id = maps:get(check_id, P, generate_id()), check_name = CN, check_type = maps:get(check_type, P, undefined)}};
new(_) -> {error, missing_required_fields}.
validate(#register_health_check_v1{division_id = V}) when not is_binary(V); byte_size(V) =:= 0 -> {error, invalid_division_id};
validate(#register_health_check_v1{check_name = N}) when not is_binary(N); byte_size(N) =:= 0 -> {error, invalid_check_name};
validate(#register_health_check_v1{} = C) -> {ok, C}.
to_map(#register_health_check_v1{} = C) -> #{<<"command_type">> => <<"register_health_check">>, <<"division_id">> => C#register_health_check_v1.division_id, <<"check_id">> => C#register_health_check_v1.check_id, <<"check_name">> => C#register_health_check_v1.check_name, <<"check_type">> => C#register_health_check_v1.check_type}.
from_map(Map) -> DI = gv(division_id, Map), CN = gv(check_name, Map),
    case {DI, CN} of {undefined,_} -> {error, missing_required_fields}; {_,undefined} -> {error, missing_required_fields};
        _ -> {ok, #register_health_check_v1{division_id = DI, check_id = gv(check_id, Map, generate_id()), check_name = CN, check_type = gv(check_type, Map, undefined)}} end.
get_division_id(#register_health_check_v1{division_id = V}) -> V.
get_check_id(#register_health_check_v1{check_id = V}) -> V.
get_check_name(#register_health_check_v1{check_name = V}) -> V.
get_check_type(#register_health_check_v1{check_type = V}) -> V.
generate_id() -> Ts = integer_to_binary(erlang:system_time(millisecond)), Rand = binary:encode_hex(crypto:strong_rand_bytes(4)), <<"check-", Ts/binary, "-", Rand/binary>>.
gv(Key, Map) -> gv(Key, Map, undefined).
gv(Key, Map, Default) when is_atom(Key) -> BK = atom_to_binary(Key, utf8), case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BK, Map) of {ok, V} -> V; error -> Default end end.
