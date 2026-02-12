-module(health_check_registered_v1).
-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_check_id/1, get_check_name/1, get_check_type/1, get_registered_at/1]).
-record(health_check_registered_v1, {division_id :: binary(), check_id :: binary(), check_name :: binary(), check_type :: binary() | undefined, registered_at :: integer()}).
-export_type([health_check_registered_v1/0]).
-opaque health_check_registered_v1() :: #health_check_registered_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).
new(#{division_id := DI, check_id := CI, check_name := CN} = P) -> #health_check_registered_v1{division_id = DI, check_id = CI, check_name = CN, check_type = maps:get(check_type, P, undefined), registered_at = erlang:system_time(millisecond)}.
to_map(#health_check_registered_v1{} = E) -> #{<<"event_type">> => <<"health_check_registered_v1">>, <<"division_id">> => E#health_check_registered_v1.division_id, <<"check_id">> => E#health_check_registered_v1.check_id, <<"check_name">> => E#health_check_registered_v1.check_name, <<"check_type">> => E#health_check_registered_v1.check_type, <<"registered_at">> => E#health_check_registered_v1.registered_at}.
from_map(Map) -> DI = gv(division_id, Map), CI = gv(check_id, Map),
    case {DI, CI} of {undefined,_} -> {error, invalid_event}; {_,undefined} -> {error, invalid_event};
        _ -> {ok, #health_check_registered_v1{division_id = DI, check_id = CI, check_name = gv(check_name, Map, <<>>), check_type = gv(check_type, Map, undefined), registered_at = gv(registered_at, Map, erlang:system_time(millisecond))}} end.
get_division_id(#health_check_registered_v1{division_id = V}) -> V.
get_check_id(#health_check_registered_v1{check_id = V}) -> V.
get_check_name(#health_check_registered_v1{check_name = V}) -> V.
get_check_type(#health_check_registered_v1{check_type = V}) -> V.
get_registered_at(#health_check_registered_v1{registered_at = V}) -> V.
gv(Key, Map) -> gv(Key, Map, undefined).
gv(Key, Map, Default) when is_atom(Key) -> BK = atom_to_binary(Key, utf8), case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BK, Map) of {ok, V} -> V; error -> Default end end.
