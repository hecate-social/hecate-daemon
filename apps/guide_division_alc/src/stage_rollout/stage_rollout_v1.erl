-module(stage_rollout_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_stage_id/1, get_release_id/1, get_stage_name/1]).
-export([generate_id/0]).
-record(stage_rollout_v1, {division_id :: binary(), stage_id :: binary(), release_id :: binary(), stage_name :: binary()}).
-export_type([stage_rollout_v1/0]).
-opaque stage_rollout_v1() :: #stage_rollout_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).
new(#{division_id := DI, release_id := RI, stage_name := SN} = P) -> {ok, #stage_rollout_v1{division_id = DI, stage_id = maps:get(stage_id, P, generate_id()), release_id = RI, stage_name = SN}};
new(_) -> {error, missing_required_fields}.
validate(#stage_rollout_v1{division_id = V}) when not is_binary(V); byte_size(V) =:= 0 -> {error, invalid_division_id};
validate(#stage_rollout_v1{stage_name = N}) when not is_binary(N); byte_size(N) =:= 0 -> {error, invalid_stage_name};
validate(#stage_rollout_v1{} = C) -> {ok, C}.
to_map(#stage_rollout_v1{} = C) -> #{<<"command_type">> => <<"stage_rollout">>, <<"division_id">> => C#stage_rollout_v1.division_id, <<"stage_id">> => C#stage_rollout_v1.stage_id, <<"release_id">> => C#stage_rollout_v1.release_id, <<"stage_name">> => C#stage_rollout_v1.stage_name}.
from_map(Map) -> DI = gv(division_id, Map), RI = gv(release_id, Map), SN = gv(stage_name, Map),
    case {DI, RI, SN} of {undefined,_,_} -> {error, missing_required_fields}; {_,undefined,_} -> {error, missing_required_fields}; {_,_,undefined} -> {error, missing_required_fields};
        _ -> {ok, #stage_rollout_v1{division_id = DI, stage_id = gv(stage_id, Map, generate_id()), release_id = RI, stage_name = SN}} end.
get_division_id(#stage_rollout_v1{division_id = V}) -> V.
get_stage_id(#stage_rollout_v1{stage_id = V}) -> V.
get_release_id(#stage_rollout_v1{release_id = V}) -> V.
get_stage_name(#stage_rollout_v1{stage_name = V}) -> V.
generate_id() -> Ts = integer_to_binary(erlang:system_time(millisecond)), Rand = binary:encode_hex(crypto:strong_rand_bytes(4)), <<"stage-", Ts/binary, "-", Rand/binary>>.
gv(Key, Map) -> gv(Key, Map, undefined).
gv(Key, Map, Default) when is_atom(Key) -> BK = atom_to_binary(Key, utf8), case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BK, Map) of {ok, V} -> V; error -> Default end end.
