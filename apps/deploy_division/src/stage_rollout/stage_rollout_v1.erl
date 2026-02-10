-module(stage_rollout_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_release_id/1, get_stage_name/1,
         get_stage_percentage/1, get_description/1]).

-record(stage_rollout_v1, {
    division_id :: binary(),
    release_id :: binary(),
    stage_name :: binary(),
    stage_percentage :: non_neg_integer(),
    description :: binary() | undefined
}).

new(#{division_id := DivisionId, release_id := ReleaseId, stage_name := StageName} = Params) ->
    Cmd = #stage_rollout_v1{
        division_id = DivisionId,
        release_id = ReleaseId,
        stage_name = StageName,
        stage_percentage = maps:get(stage_percentage, Params, 0),
        description = maps:get(description, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#stage_rollout_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#stage_rollout_v1{release_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, release_id}};
validate(#stage_rollout_v1{stage_name = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, stage_name}};
validate(_) -> ok.

to_map(#stage_rollout_v1{division_id = DI, release_id = RI, stage_name = SN,
                          stage_percentage = SP, description = D}) ->
    #{
        <<"command_type">> => <<"stage_rollout">>,
        <<"division_id">> => DI,
        <<"release_id">> => RI,
        <<"stage_name">> => SN,
        <<"stage_percentage">> => SP,
        <<"description">> => D
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    ReleaseId = get_val(release_id, Map),
    StageName = get_val(stage_name, Map),
    StagePercentage = get_val(stage_percentage, Map),
    Description = get_val(description, Map),
    new(#{division_id => DivisionId, release_id => ReleaseId,
          stage_name => StageName, stage_percentage => StagePercentage,
          description => Description}).

get_division_id(#stage_rollout_v1{division_id = V}) -> V.
get_release_id(#stage_rollout_v1{release_id = V}) -> V.
get_stage_name(#stage_rollout_v1{stage_name = V}) -> V.
get_stage_percentage(#stage_rollout_v1{stage_percentage = V}) -> V.
get_description(#stage_rollout_v1{description = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
