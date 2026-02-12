-module(fix_applied_v1).
-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_fix_id/1, get_incident_id/1, get_description/1, get_applied_at/1]).
-record(fix_applied_v1, {division_id :: binary(), fix_id :: binary(), incident_id :: binary(), description :: binary() | undefined, applied_at :: integer()}).
-export_type([fix_applied_v1/0]).
-opaque fix_applied_v1() :: #fix_applied_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).
new(#{division_id := DI, fix_id := FI, incident_id := II} = P) -> #fix_applied_v1{division_id = DI, fix_id = FI, incident_id = II, description = maps:get(description, P, undefined), applied_at = erlang:system_time(millisecond)}.
to_map(#fix_applied_v1{} = E) -> #{<<"event_type">> => <<"fix_applied_v1">>, <<"division_id">> => E#fix_applied_v1.division_id, <<"fix_id">> => E#fix_applied_v1.fix_id, <<"incident_id">> => E#fix_applied_v1.incident_id, <<"description">> => E#fix_applied_v1.description, <<"applied_at">> => E#fix_applied_v1.applied_at}.
from_map(Map) -> DI = gv(division_id, Map), FI = gv(fix_id, Map),
    case {DI, FI} of {undefined,_} -> {error, invalid_event}; {_,undefined} -> {error, invalid_event};
        _ -> {ok, #fix_applied_v1{division_id = DI, fix_id = FI, incident_id = gv(incident_id, Map, <<>>), description = gv(description, Map, undefined), applied_at = gv(applied_at, Map, erlang:system_time(millisecond))}} end.
get_division_id(#fix_applied_v1{division_id = V}) -> V.
get_fix_id(#fix_applied_v1{fix_id = V}) -> V.
get_incident_id(#fix_applied_v1{incident_id = V}) -> V.
get_description(#fix_applied_v1{description = V}) -> V.
get_applied_at(#fix_applied_v1{applied_at = V}) -> V.
gv(Key, Map) -> gv(Key, Map, undefined).
gv(Key, Map, Default) when is_atom(Key) -> BK = atom_to_binary(Key, utf8), case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BK, Map) of {ok, V} -> V; error -> Default end end.
