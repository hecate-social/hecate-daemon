%%% @doc release_deployed_v1 event
-module(release_deployed_v1).
-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_release_id/1, get_version/1, get_deployed_at/1]).
-record(release_deployed_v1, {division_id :: binary(), release_id :: binary(), version :: binary(), deployed_at :: integer()}).
-export_type([release_deployed_v1/0]).
-opaque release_deployed_v1() :: #release_deployed_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).

new(#{division_id := DivisionId, release_id := ReleaseId, version := Version} = _Params) ->
    #release_deployed_v1{division_id = DivisionId, release_id = ReleaseId, version = Version, deployed_at = erlang:system_time(millisecond)}.

to_map(#release_deployed_v1{} = E) ->
    #{<<"event_type">> => <<"release_deployed_v1">>, <<"division_id">> => E#release_deployed_v1.division_id,
      <<"release_id">> => E#release_deployed_v1.release_id, <<"version">> => E#release_deployed_v1.version,
      <<"deployed_at">> => E#release_deployed_v1.deployed_at}.

from_map(Map) ->
    DivisionId = get_value(division_id, Map), ReleaseId = get_value(release_id, Map),
    case {DivisionId, ReleaseId} of
        {undefined, _} -> {error, invalid_event}; {_, undefined} -> {error, invalid_event};
        _ -> {ok, #release_deployed_v1{division_id = DivisionId, release_id = ReleaseId,
              version = get_value(version, Map, <<>>), deployed_at = get_value(deployed_at, Map, erlang:system_time(millisecond))}}
    end.

get_division_id(#release_deployed_v1{division_id = V}) -> V.
get_release_id(#release_deployed_v1{release_id = V}) -> V.
get_version(#release_deployed_v1{version = V}) -> V.
get_deployed_at(#release_deployed_v1{deployed_at = V}) -> V.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) -> BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BinKey, Map) of {ok, V} -> V; error -> Default end end.
