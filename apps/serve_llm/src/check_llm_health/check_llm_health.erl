%%% @doc Check LLM Health
%%% Checks health of all configured providers.
-module(check_llm_health).

-export([check/0, check_all/0]).

%% @doc Check health of all providers. Returns ok if any provider is healthy.
-spec check() -> ok | {error, term()}.
check() ->
    case check_all() of
        #{} = Results ->
            HasHealthy = maps:fold(fun(_Name, Status, Acc) ->
                Acc orelse (Status =:= ok)
            end, false, Results),
            case HasHealthy of
                true -> ok;
                false -> {error, all_providers_unhealthy}
            end
    end.

%% @doc Check health of each provider, returns per-provider status map.
-spec check_all() -> #{binary() => ok | {error, term()}}.
check_all() ->
    Providers = manage_providers:list(),
    maps:fold(fun(Name, #{type := Type} = Config, Acc) ->
        case maps:get(enabled, Config, true) of
            true ->
                Mod = llm_provider:provider_module(Type),
                Acc#{Name => Mod:health(Config)};
            false ->
                Acc#{Name => {error, disabled}}
        end
    end, #{}, Providers).
