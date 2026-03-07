%%% @doc API handler for LLM usage cost tracking.
%%%
%%% GET  /api/llm/usage/cost              - Get total cost
%%% GET  /api/llm/usage/cost/:venture_id  - Get cost for a venture
%%% @end
-module(track_llm_usage_api).

-export([init/2, routes/0]).

routes() ->
    [{"/api/llm/usage/cost", ?MODULE, [total_cost]},
     {"/api/llm/usage/cost/:venture_id", ?MODULE, [cost_by_venture]}].

init(Req0, [total_cost]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_total_cost(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end;
init(Req0, [cost_by_venture]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_cost_by_venture(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_total_cost(Req0) ->
    {ok, Cost} = project_llm_usage_store:get_total_cost(),
    hecate_api_utils:json_ok(#{total_cost_usd => Cost, currency => <<"USD">>}, Req0).

handle_cost_by_venture(Req0) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    {ok, Cost} = project_llm_usage_store:get_cost_by_venture(VentureId),
    hecate_api_utils:json_ok(#{venture_id => VentureId, cost_usd => Cost, currency => <<"USD">>}, Req0).
