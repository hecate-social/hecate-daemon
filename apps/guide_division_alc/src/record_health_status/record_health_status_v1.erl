-module(record_health_status_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_check_id/1, get_status/1]).
-record(record_health_status_v1, {division_id :: binary(), check_id :: binary(), status :: binary()}).
-export_type([record_health_status_v1/0]).
-opaque record_health_status_v1() :: #record_health_status_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).
new(#{division_id := DI, check_id := CI, status := S} = _P) -> {ok, #record_health_status_v1{division_id = DI, check_id = CI, status = S}};
new(_) -> {error, missing_required_fields}.
validate(#record_health_status_v1{division_id = V}) when not is_binary(V); byte_size(V) =:= 0 -> {error, invalid_division_id};
validate(#record_health_status_v1{check_id = C}) when not is_binary(C); byte_size(C) =:= 0 -> {error, invalid_check_id};
validate(#record_health_status_v1{} = Cmd) -> {ok, Cmd}.
to_map(#record_health_status_v1{} = C) -> #{<<"command_type">> => <<"record_health_status">>, <<"division_id">> => C#record_health_status_v1.division_id, <<"check_id">> => C#record_health_status_v1.check_id, <<"status">> => C#record_health_status_v1.status}.
from_map(Map) -> DI = gv(division_id, Map), CI = gv(check_id, Map), S = gv(status, Map),
    case {DI, CI, S} of {undefined,_,_} -> {error, missing_required_fields}; {_,undefined,_} -> {error, missing_required_fields}; {_,_,undefined} -> {error, missing_required_fields};
        _ -> {ok, #record_health_status_v1{division_id = DI, check_id = CI, status = S}} end.
get_division_id(#record_health_status_v1{division_id = V}) -> V.
get_check_id(#record_health_status_v1{check_id = V}) -> V.
get_status(#record_health_status_v1{status = V}) -> V.
gv(Key, Map) -> gv(Key, Map, undefined).
gv(Key, Map, Default) when is_atom(Key) -> BK = atom_to_binary(Key, utf8), case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BK, Map) of {ok, V} -> V; error -> Default end end.
