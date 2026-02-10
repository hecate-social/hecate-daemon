-module(deploy_release_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_release_name/1, get_release_version/1,
         get_target_env/1, get_deployed_by/1]).

-record(deploy_release_v1, {
    division_id :: binary(),
    release_name :: binary(),
    release_version :: binary(),
    target_env :: binary(),
    deployed_by :: binary() | undefined
}).

new(#{division_id := DivisionId, release_name := ReleaseName} = Params) ->
    Cmd = #deploy_release_v1{
        division_id = DivisionId,
        release_name = ReleaseName,
        release_version = maps:get(release_version, Params, <<>>),
        target_env = maps:get(target_env, Params, <<>>),
        deployed_by = maps:get(deployed_by, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#deploy_release_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#deploy_release_v1{release_name = N}) when not is_binary(N); N =:= <<>> ->
    {error, {invalid_field, release_name}};
validate(_) -> ok.

to_map(#deploy_release_v1{division_id = DI, release_name = RN, release_version = RV,
                           target_env = TE, deployed_by = DB}) ->
    #{
        <<"command_type">> => <<"deploy_release">>,
        <<"division_id">> => DI,
        <<"release_name">> => RN,
        <<"release_version">> => RV,
        <<"target_env">> => TE,
        <<"deployed_by">> => DB
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    ReleaseName = get_val(release_name, Map),
    ReleaseVersion = get_val(release_version, Map),
    TargetEnv = get_val(target_env, Map),
    DeployedBy = get_val(deployed_by, Map),
    new(#{division_id => DivisionId, release_name => ReleaseName,
          release_version => ReleaseVersion, target_env => TargetEnv,
          deployed_by => DeployedBy}).

get_division_id(#deploy_release_v1{division_id = V}) -> V.
get_release_name(#deploy_release_v1{release_name = V}) -> V.
get_release_version(#deploy_release_v1{release_version = V}) -> V.
get_target_env(#deploy_release_v1{target_env = V}) -> V.
get_deployed_by(#deploy_release_v1{deployed_by = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
