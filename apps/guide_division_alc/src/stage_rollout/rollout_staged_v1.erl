-module(rollout_staged_v1).
-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_stage_id/1, get_release_id/1, get_stage_name/1, get_staged_at/1]).
-record(rollout_staged_v1, {division_id :: binary(), stage_id :: binary(), release_id :: binary(), stage_name :: binary(), staged_at :: integer()}).
-export_type([rollout_staged_v1/0]).
-opaque rollout_staged_v1() :: #rollout_staged_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).
new(#{division_id := DI, stage_id := SI, release_id := RI, stage_name := SN} = _P) -> #rollout_staged_v1{division_id = DI, stage_id = SI, release_id = RI, stage_name = SN, staged_at = erlang:system_time(millisecond)}.
to_map(#rollout_staged_v1{} = E) -> #{<<"event_type">> => <<"rollout_staged_v1">>, <<"division_id">> => E#rollout_staged_v1.division_id, <<"stage_id">> => E#rollout_staged_v1.stage_id, <<"release_id">> => E#rollout_staged_v1.release_id, <<"stage_name">> => E#rollout_staged_v1.stage_name, <<"staged_at">> => E#rollout_staged_v1.staged_at}.
from_map(Map) -> DI = gv(division_id, Map), SI = gv(stage_id, Map),
    case {DI, SI} of {undefined,_} -> {error, invalid_event}; {_,undefined} -> {error, invalid_event};
        _ -> {ok, #rollout_staged_v1{division_id = DI, stage_id = SI, release_id = gv(release_id, Map, <<>>), stage_name = gv(stage_name, Map, <<>>), staged_at = gv(staged_at, Map, erlang:system_time(millisecond))}} end.
get_division_id(#rollout_staged_v1{division_id = V}) -> V.
get_stage_id(#rollout_staged_v1{stage_id = V}) -> V.
get_release_id(#rollout_staged_v1{release_id = V}) -> V.
get_stage_name(#rollout_staged_v1{stage_name = V}) -> V.
get_staged_at(#rollout_staged_v1{staged_at = V}) -> V.
gv(Key, Map) -> gv(Key, Map, undefined).
gv(Key, Map, Default) when is_atom(Key) -> BK = atom_to_binary(Key, utf8), case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BK, Map) of {ok, V} -> V; error -> Default end end.
