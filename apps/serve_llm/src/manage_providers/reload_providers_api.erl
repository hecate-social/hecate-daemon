%%% @doc API handler: POST /api/llm/providers/reload
%%%
%%% Reload providers from disk and re-detect from environment variables.
%%% Useful for picking up new API keys without restarting the daemon.
%%% @end
-module(reload_providers_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    ok = manage_providers:reload(),
    Providers = manage_providers:list(),
    ProviderNames = maps:keys(Providers),
    hecate_api_utils:json_ok(#{providers => ProviderNames}, Req0).
