%%% @doc API handler: GET /api/llm/health
%%%
%%% Check health of all LLM providers.
%%% Returns 200 if any provider is healthy, 503 if all are unhealthy.
%%% @end
-module(check_llm_health_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    ProviderHealth = check_llm_health:check_all(),
    AnyHealthy = maps:fold(fun(_Name, ok, _) -> true;
                              (_Name, _, Acc) -> Acc
                           end, false, ProviderHealth),
    Status = case AnyHealthy of
        true -> <<"healthy">>;
        false -> <<"unhealthy">>
    end,
    StatusCode = case AnyHealthy of
        true -> 200;
        false -> 503
    end,
    Providers = maps:map(fun(_Name, ok) -> <<"healthy">>;
                            (_Name, {error, Reason}) -> hecate_api_utils:format_error(Reason)
                         end, ProviderHealth),
    hecate_api_utils:json_response(StatusCode, #{
        ok => AnyHealthy,
        status => Status,
        providers => Providers
    }, Req0).
