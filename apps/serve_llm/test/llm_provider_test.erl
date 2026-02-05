%%% @doc Tests for llm_provider module
-module(llm_provider_test).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% provider_module/1 tests
%% ===================================================================

ollama_maps_to_ollama_provider_test() ->
    ?assertEqual(ollama_provider, llm_provider:provider_module(ollama)).

openai_maps_to_openai_provider_test() ->
    ?assertEqual(openai_provider, llm_provider:provider_module(openai)).

anthropic_maps_to_anthropic_provider_test() ->
    ?assertEqual(anthropic_provider, llm_provider:provider_module(anthropic)).

google_maps_to_google_provider_test() ->
    ?assertEqual(google_provider, llm_provider:provider_module(google)).

%% ===================================================================
%% module exports test
%% ===================================================================

module_exports_provider_module_test() ->
    Exports = llm_provider:module_info(exports),
    ?assert(lists:member({provider_module, 1}, Exports)).
