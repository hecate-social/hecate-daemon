-module(release_deployed_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_division_id/1, get_release_id/1, get_release_name/1,
         get_release_version/1, get_target_env/1, get_deployed_by/1,
         get_deployed_at/1]).

-record(release_deployed_v1, {
    division_id :: binary(),
    release_id :: binary(),
    release_name :: binary(),
    release_version :: binary(),
    target_env :: binary(),
    deployed_by :: binary() | undefined,
    deployed_at :: non_neg_integer()
}).

new(#{division_id := DivisionId, release_name := ReleaseName} = Params) ->
    #release_deployed_v1{
        division_id = DivisionId,
        release_id = maps:get(release_id, Params, generate_release_id(DivisionId, ReleaseName)),
        release_name = ReleaseName,
        release_version = maps:get(release_version, Params, <<>>),
        target_env = maps:get(target_env, Params, <<>>),
        deployed_by = maps:get(deployed_by, Params, undefined),
        deployed_at = maps:get(deployed_at, Params, erlang:system_time(millisecond))
    }.

to_map(#release_deployed_v1{division_id = DI, release_id = RI, release_name = RN,
                             release_version = RV, target_env = TE,
                             deployed_by = DB, deployed_at = DA}) ->
    #{
        <<"event_type">> => <<"release_deployed_v1">>,
        <<"division_id">> => DI,
        <<"release_id">> => RI,
        <<"release_name">> => RN,
        <<"release_version">> => RV,
        <<"target_env">> => TE,
        <<"deployed_by">> => DB,
        <<"deployed_at">> => DA
    }.

from_map(Map) ->
    {ok, #release_deployed_v1{
        division_id = get_val(division_id, Map),
        release_id = get_val(release_id, Map),
        release_name = get_val(release_name, Map),
        release_version = get_val(release_version, Map),
        target_env = get_val(target_env, Map),
        deployed_by = get_val(deployed_by, Map),
        deployed_at = get_val(deployed_at, Map)
    }}.

get_division_id(#release_deployed_v1{division_id = V}) -> V.
get_release_id(#release_deployed_v1{release_id = V}) -> V.
get_release_name(#release_deployed_v1{release_name = V}) -> V.
get_release_version(#release_deployed_v1{release_version = V}) -> V.
get_target_env(#release_deployed_v1{target_env = V}) -> V.
get_deployed_by(#release_deployed_v1{deployed_by = V}) -> V.
get_deployed_at(#release_deployed_v1{deployed_at = V}) -> V.

generate_release_id(DivisionId, ReleaseName) ->
    <<"rel-", DivisionId/binary, "-", ReleaseName/binary>>.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
