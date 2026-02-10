-module(rollout_staged_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_division_id/1, get_stage_id/1, get_release_id/1,
         get_stage_name/1, get_stage_percentage/1, get_description/1,
         get_staged_at/1]).

-record(rollout_staged_v1, {
    division_id :: binary(),
    stage_id :: binary(),
    release_id :: binary(),
    stage_name :: binary(),
    stage_percentage :: non_neg_integer(),
    description :: binary() | undefined,
    staged_at :: non_neg_integer()
}).

new(#{division_id := DivisionId, release_id := ReleaseId, stage_name := StageName} = Params) ->
    #rollout_staged_v1{
        division_id = DivisionId,
        stage_id = maps:get(stage_id, Params, generate_stage_id(ReleaseId, StageName)),
        release_id = ReleaseId,
        stage_name = StageName,
        stage_percentage = maps:get(stage_percentage, Params, 0),
        description = maps:get(description, Params, undefined),
        staged_at = maps:get(staged_at, Params, erlang:system_time(millisecond))
    }.

to_map(#rollout_staged_v1{division_id = DI, stage_id = SI, release_id = RI,
                           stage_name = SN, stage_percentage = SP,
                           description = D, staged_at = SA}) ->
    #{
        <<"event_type">> => <<"rollout_staged_v1">>,
        <<"division_id">> => DI,
        <<"stage_id">> => SI,
        <<"release_id">> => RI,
        <<"stage_name">> => SN,
        <<"stage_percentage">> => SP,
        <<"description">> => D,
        <<"staged_at">> => SA
    }.

from_map(Map) ->
    {ok, #rollout_staged_v1{
        division_id = get_val(division_id, Map),
        stage_id = get_val(stage_id, Map),
        release_id = get_val(release_id, Map),
        stage_name = get_val(stage_name, Map),
        stage_percentage = get_val(stage_percentage, Map),
        description = get_val(description, Map),
        staged_at = get_val(staged_at, Map)
    }}.

get_division_id(#rollout_staged_v1{division_id = V}) -> V.
get_stage_id(#rollout_staged_v1{stage_id = V}) -> V.
get_release_id(#rollout_staged_v1{release_id = V}) -> V.
get_stage_name(#rollout_staged_v1{stage_name = V}) -> V.
get_stage_percentage(#rollout_staged_v1{stage_percentage = V}) -> V.
get_description(#rollout_staged_v1{description = V}) -> V.
get_staged_at(#rollout_staged_v1{staged_at = V}) -> V.

generate_stage_id(ReleaseId, StageName) ->
    <<"stage-", ReleaseId/binary, "-", StageName/binary>>.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
