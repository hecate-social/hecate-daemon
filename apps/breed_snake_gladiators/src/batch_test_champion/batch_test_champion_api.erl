%%% @doc API handler: POST /api/arcade/gladiators/stables/:stable_id/batch-test
%%%
%%% Runs N headless duels for a champion and returns aggregated stats.
%%% The champion neural network plays against the heuristic AI opponent
%%% without any timers, countdowns, or SSE broadcasting.
%%%
%%% Request body:
%%%   rank        - Champion rank to test (default 1)
%%%   opponent_af - Opponent asshole factor 0-100 (default 50)
%%%   num_duels   - Number of duels to run 1-100 (default 20)
%%%
%%% Response: aggregated win/loss/draw stats with averages.
%%% @end
-module(batch_test_champion_api).

-include("gladiator.hrl").

-export([init/2, routes/0]).

routes() -> [{"/api/arcade/gladiators/stables/:stable_id/batch-test", ?MODULE, []}].

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0) ->
    StableId = cowboy_req:binding(stable_id, Req0),
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            Rank = to_integer(hecate_api_utils:get_field(rank, Params), 1),
            OppAF = clamp(to_integer(hecate_api_utils:get_field(opponent_af, Params), 50), 0, 100),
            NumDuels = clamp(to_integer(hecate_api_utils:get_field(num_duels, Params), 20), 1, 100),

            case load_champion_network(StableId, Rank) of
                {ok, Network} ->
                    Results = headless_champion_duel:run_batch(Network, OppAF, NumDuels),
                    %% Strip NIF ref to prevent memory leak
                    network_evaluator:strip_compiled_ref(Network),
                    hecate_api_utils:json_ok(200, #{
                        ok => true,
                        results => Results
                    }, Req1);
                {error, not_found} ->
                    hecate_api_utils:json_error(404, <<"Champion not found">>, Req1);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, hecate_api_utils:format_error(Reason), Req1)
            end;
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

load_champion_network(StableId, Rank) ->
    case query_snake_gladiators_store:get_champion(StableId, Rank) of
        {ok, #{network_json := NetworkJson}} ->
            NetworkData0 = json:decode(NetworkJson),
            NetworkData = maybe_start_champion_duel:maybe_migrate_topology(NetworkData0),
            case network_evaluator:from_json(NetworkData) of
                {ok, Network} ->
                    %% Compile for NIF (standard) or reset internal state (CfC)
                    Prepared = case network_evaluator:get_neuron_meta(Network) of
                        undefined -> network_evaluator:compile_for_nif(Network);
                        _CfcMeta -> network_evaluator:reset_internal_state(Network)
                    end,
                    {ok, Prepared};
                {error, _} = Err ->
                    Err
            end;
        {error, not_found} ->
            {error, not_found}
    end.

clamp(Value, Min, Max) ->
    max(Min, min(Max, Value)).

to_integer(V, _Default) when is_integer(V) -> V;
to_integer(V, _Default) when is_float(V) -> round(V);
to_integer(V, _Default) when is_binary(V) ->
    try binary_to_integer(V) catch _:_ -> 0 end;
to_integer(_, Default) -> Default.
