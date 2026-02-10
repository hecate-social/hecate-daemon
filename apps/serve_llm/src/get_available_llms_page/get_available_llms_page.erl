%%% @doc List Available LLMs
%%% Aggregates models from all configured providers.
-module(get_available_llms_page).

-export([list/0]).

-spec list() -> {ok, list()} | {error, term()}.
list() ->
    Providers = manage_providers:list(),
    AllModels = maps:fold(fun(Name, #{type := Type} = Config, Acc) ->
        case maps:get(enabled, Config, true) of
            true ->
                Mod = llm_provider:provider_module(Type),
                case Mod:list_models(Config) of
                    {ok, Models} ->
                        Tagged = [M#{provider => Name} || M <- Models],
                        Acc ++ Tagged;
                    {error, _} ->
                        Acc
                end;
            false ->
                Acc
        end
    end, [], Providers),
    {ok, AllModels}.
