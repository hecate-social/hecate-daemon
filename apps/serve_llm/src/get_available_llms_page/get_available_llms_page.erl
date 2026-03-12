%%% @doc List Available LLMs
%%% Returns validated models from the provider cache. Models that failed
%%% availability probes during cache build are excluded.
-module(get_available_llms_page).

-export([list/0]).

-spec list() -> {ok, list()} | {error, term()}.
list() ->
    manage_providers:list_all_models().
