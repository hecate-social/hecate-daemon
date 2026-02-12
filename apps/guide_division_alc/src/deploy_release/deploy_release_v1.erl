%%% @doc deploy_release_v1 command
-module(deploy_release_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_release_id/1, get_version/1]).
-export([generate_id/0]).
-record(deploy_release_v1, {division_id :: binary(), release_id :: binary(), version :: binary()}).
-export_type([deploy_release_v1/0]).
-opaque deploy_release_v1() :: #deploy_release_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).

new(#{division_id := DivisionId, version := Version} = Params) ->
    {ok, #deploy_release_v1{division_id = DivisionId, release_id = maps:get(release_id, Params, generate_id()), version = Version}};
new(_) -> {error, missing_required_fields}.

validate(#deploy_release_v1{division_id = V}) when not is_binary(V); byte_size(V) =:= 0 -> {error, invalid_division_id};
validate(#deploy_release_v1{version = V}) when not is_binary(V); byte_size(V) =:= 0 -> {error, invalid_version};
validate(#deploy_release_v1{} = Cmd) -> {ok, Cmd}.

to_map(#deploy_release_v1{} = C) ->
    #{<<"command_type">> => <<"deploy_release">>, <<"division_id">> => C#deploy_release_v1.division_id,
      <<"release_id">> => C#deploy_release_v1.release_id, <<"version">> => C#deploy_release_v1.version}.

from_map(Map) ->
    DivisionId = get_value(division_id, Map), Version = get_value(version, Map),
    case {DivisionId, Version} of
        {undefined, _} -> {error, missing_required_fields}; {_, undefined} -> {error, missing_required_fields};
        _ -> {ok, #deploy_release_v1{division_id = DivisionId, release_id = get_value(release_id, Map, generate_id()), version = Version}}
    end.

get_division_id(#deploy_release_v1{division_id = V}) -> V.
get_release_id(#deploy_release_v1{release_id = V}) -> V.
get_version(#deploy_release_v1{version = V}) -> V.
generate_id() -> Ts = integer_to_binary(erlang:system_time(millisecond)), Rand = binary:encode_hex(crypto:strong_rand_bytes(4)), <<"release-", Ts/binary, "-", Rand/binary>>.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) -> BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BinKey, Map) of {ok, V} -> V; error -> Default end end.
