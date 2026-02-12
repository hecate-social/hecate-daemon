-module(health_status_recorded_v1).
-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_check_id/1, get_status/1, get_recorded_at/1]).
-record(health_status_recorded_v1, {division_id :: binary(), check_id :: binary(), status :: binary(), recorded_at :: integer()}).
-export_type([health_status_recorded_v1/0]).
-opaque health_status_recorded_v1() :: #health_status_recorded_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).
new(#{division_id := DI, check_id := CI, status := S} = _P) -> #health_status_recorded_v1{division_id = DI, check_id = CI, status = S, recorded_at = erlang:system_time(millisecond)}.
to_map(#health_status_recorded_v1{} = E) -> #{<<"event_type">> => <<"health_status_recorded_v1">>, <<"division_id">> => E#health_status_recorded_v1.division_id, <<"check_id">> => E#health_status_recorded_v1.check_id, <<"status">> => E#health_status_recorded_v1.status, <<"recorded_at">> => E#health_status_recorded_v1.recorded_at}.
from_map(Map) -> DI = gv(division_id, Map), CI = gv(check_id, Map),
    case {DI, CI} of {undefined,_} -> {error, invalid_event}; {_,undefined} -> {error, invalid_event};
        _ -> {ok, #health_status_recorded_v1{division_id = DI, check_id = CI, status = gv(status, Map, <<>>), recorded_at = gv(recorded_at, Map, erlang:system_time(millisecond))}} end.
get_division_id(#health_status_recorded_v1{division_id = V}) -> V.
get_check_id(#health_status_recorded_v1{check_id = V}) -> V.
get_status(#health_status_recorded_v1{status = V}) -> V.
get_recorded_at(#health_status_recorded_v1{recorded_at = V}) -> V.
gv(Key, Map) -> gv(Key, Map, undefined).
gv(Key, Map, Default) when is_atom(Key) -> BK = atom_to_binary(Key, utf8), case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BK, Map) of {ok, V} -> V; error -> Default end end.
