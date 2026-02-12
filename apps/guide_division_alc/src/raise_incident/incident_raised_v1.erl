-module(incident_raised_v1).
-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_incident_id/1, get_title/1, get_severity/1, get_raised_at/1]).
-record(incident_raised_v1, {division_id :: binary(), incident_id :: binary(), title :: binary(), severity :: binary() | undefined, raised_at :: integer()}).
-export_type([incident_raised_v1/0]).
-opaque incident_raised_v1() :: #incident_raised_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).
new(#{division_id := DI, incident_id := II, title := T} = P) -> #incident_raised_v1{division_id = DI, incident_id = II, title = T, severity = maps:get(severity, P, undefined), raised_at = erlang:system_time(millisecond)}.
to_map(#incident_raised_v1{} = E) -> #{<<"event_type">> => <<"incident_raised_v1">>, <<"division_id">> => E#incident_raised_v1.division_id, <<"incident_id">> => E#incident_raised_v1.incident_id, <<"title">> => E#incident_raised_v1.title, <<"severity">> => E#incident_raised_v1.severity, <<"raised_at">> => E#incident_raised_v1.raised_at}.
from_map(Map) -> DI = gv(division_id, Map), II = gv(incident_id, Map),
    case {DI, II} of {undefined,_} -> {error, invalid_event}; {_,undefined} -> {error, invalid_event};
        _ -> {ok, #incident_raised_v1{division_id = DI, incident_id = II, title = gv(title, Map, <<>>), severity = gv(severity, Map, undefined), raised_at = gv(raised_at, Map, erlang:system_time(millisecond))}} end.
get_division_id(#incident_raised_v1{division_id = V}) -> V.
get_incident_id(#incident_raised_v1{incident_id = V}) -> V.
get_title(#incident_raised_v1{title = V}) -> V.
get_severity(#incident_raised_v1{severity = V}) -> V.
get_raised_at(#incident_raised_v1{raised_at = V}) -> V.
gv(Key, Map) -> gv(Key, Map, undefined).
gv(Key, Map, Default) when is_atom(Key) -> BK = atom_to_binary(Key, utf8), case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BK, Map) of {ok, V} -> V; error -> Default end end.
