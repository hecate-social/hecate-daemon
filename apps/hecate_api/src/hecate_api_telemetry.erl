%%% @doc Telemetry API endpoints.
%%%
%%% Provides REST interface to LLM cost tracking and telemetry:
%%% - GET  /api/telemetry/cost                      - Get total cost
%%% - GET  /api/telemetry/cost/:torch_id            - Get cost for a torch
%%% - GET  /api/telemetry/cost/:torch_id/cartwheels - Get cost breakdown by cartwheel
%%% - GET  /api/telemetry/cost/:torch_id/agents     - Get cost breakdown by agent
%%%
%%% @end
-module(hecate_api_telemetry).

-export([init/2]).

%% Route: GET /api/telemetry/cost
init(Req0, [total_cost]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_total_cost(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: GET /api/telemetry/cost/:torch_id
init(Req0, [cost_by_torch]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_cost_by_torch(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: GET /api/telemetry/cost/:torch_id/cartwheels
init(Req0, [cost_by_cartwheel]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_cost_by_cartwheel(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

%% Route: GET /api/telemetry/cost/:torch_id/agents
init(Req0, [cost_by_agent]) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_cost_by_agent(Req0);
        _ ->
            method_not_allowed(Req0)
    end;

init(Req0, _State) ->
    not_found(Req0).

%%% ===================================================================
%%% Handlers
%%% ===================================================================

%% @doc Get total cost across all LLM calls.
handle_total_cost(Req0) ->
    case hecate_telemetry_store:get_total_cost() of
        {ok, Cost} ->
            json_response(200, #{
                ok => true,
                total_cost_usd => Cost,
                currency => <<"USD">>
            }, Req0);
        {error, Reason} ->
            json_response(500, #{ok => false, error => format_error(Reason)}, Req0)
    end.

%% @doc Get cost for a specific torch.
handle_cost_by_torch(Req0) ->
    TorchId = cowboy_req:binding(torch_id, Req0),
    case hecate_telemetry_store:get_cost_by_torch(TorchId) of
        {ok, Cost} ->
            json_response(200, #{
                ok => true,
                torch_id => TorchId,
                cost_usd => Cost,
                currency => <<"USD">>
            }, Req0);
        {error, Reason} ->
            json_response(500, #{ok => false, error => format_error(Reason)}, Req0)
    end.

%% @doc Get cost breakdown by cartwheel for a torch.
%% Skeleton implementation - returns empty map until full implementation.
handle_cost_by_cartwheel(Req0) ->
    TorchId = cowboy_req:binding(torch_id, Req0),

    %% TODO: Implement proper cartwheel cost breakdown
    %% This would require querying the telemetry store for all cartwheels
    %% within the torch and aggregating their costs.
    %%
    %% For now, return skeleton response with empty breakdown.
    json_response(200, #{
        ok => true,
        torch_id => TorchId,
        cartwheels => #{},
        currency => <<"USD">>,
        note => <<"Cartwheel breakdown not yet implemented">>
    }, Req0).

%% @doc Get cost breakdown by agent for a torch.
%% Skeleton implementation - returns empty map until full implementation.
handle_cost_by_agent(Req0) ->
    TorchId = cowboy_req:binding(torch_id, Req0),

    %% TODO: Implement proper agent cost breakdown
    %% This would require querying the telemetry store for all agents
    %% within the torch and aggregating their costs.
    %%
    %% For now, return skeleton response with empty breakdown.
    json_response(200, #{
        ok => true,
        torch_id => TorchId,
        agents => #{},
        currency => <<"USD">>,
        note => <<"Agent breakdown not yet implemented">>
    }, Req0).

%%% ===================================================================
%%% Internal helpers
%%% ===================================================================

format_error(Reason) when is_binary(Reason) -> Reason;
format_error(Reason) when is_atom(Reason) -> atom_to_binary(Reason);
format_error({Type, Details}) ->
    iolist_to_binary(io_lib:format("~p: ~p", [Type, Details]));
format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).

json_response(StatusCode, Body, Req0) ->
    JsonBody = json:encode(Body),
    Req = cowboy_req:reply(StatusCode, #{
        <<"content-type">> => <<"application/json">>
    }, JsonBody, Req0),
    {ok, Req, []}.

method_not_allowed(Req0) ->
    json_response(405, #{ok => false, error => <<"Method not allowed">>}, Req0).

not_found(Req0) ->
    json_response(404, #{ok => false, error => <<"Not found">>}, Req0).
