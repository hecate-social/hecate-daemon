%%% @doc API handler: GET /api/arcade/gladiators/fitness/presets
%%%
%%% Returns available fitness weight presets and budget info.
%%% @end
-module(fitness_presets_api).

-include("gladiator.hrl").

-export([init/2]).

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0) ->
    Presets = gladiator_fitness_config:presets(),
    %% Compute tuning cost for each preset
    PresetsWithCost = maps:map(
        fun(_Name, Weights) ->
            #{weights => Weights,
              tuning_cost => gladiator_fitness_config:tuning_cost(Weights)}
        end,
        Presets
    ),
    Response = #{
        ok => true,
        presets => PresetsWithCost,
        defaults => ?DEFAULT_FITNESS_WEIGHTS,
        bounds => maps:map(
            fun(_K, {Min, Max}) -> #{min => Min, max => Max} end,
            ?FITNESS_WEIGHT_BOUNDS
        ),
        budget => ?DEFAULT_TUNING_BUDGET
    },
    hecate_api_utils:json_ok(200, Response, Req0).
