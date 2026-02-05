%%% @doc Tests for anthropic_provider module
-module(anthropic_provider_test).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Module export verification
%% ===================================================================

exports_list_models_test() ->
    Exports = anthropic_provider:module_info(exports),
    ?assert(lists:member({list_models, 1}, Exports)).

exports_chat_test() ->
    Exports = anthropic_provider:module_info(exports),
    ?assert(lists:member({chat, 4}, Exports)).

exports_chat_stream_test() ->
    Exports = anthropic_provider:module_info(exports),
    ?assert(lists:member({chat_stream, 6}, Exports)).

exports_health_test() ->
    Exports = anthropic_provider:module_info(exports),
    ?assert(lists:member({health, 1}, Exports)).

%% ===================================================================
%% Behaviour verification
%% ===================================================================

implements_llm_provider_behaviour_test() ->
    Attrs = anthropic_provider:module_info(attributes),
    Behaviours = proplists:get_value(behaviour, Attrs, []),
    ?assert(lists:member(llm_provider, Behaviours)).

%% ===================================================================
%% list_models/1 returns hardcoded models (no HTTP needed)
%% ===================================================================

list_models_returns_three_models_test() ->
    {ok, Models} = anthropic_provider:list_models(#{}),
    ?assertEqual(3, length(Models)).

list_models_first_model_is_opus_test() ->
    {ok, [M1 | _]} = anthropic_provider:list_models(#{}),
    ?assertEqual(<<"claude-opus-4-5-20251101">>, maps:get(name, M1)),
    ?assertEqual(200000, maps:get(context_length, M1)),
    ?assertEqual(<<"claude">>, maps:get(family, M1)).

list_models_second_model_is_sonnet_test() ->
    {ok, [_, M2 | _]} = anthropic_provider:list_models(#{}),
    ?assertEqual(<<"claude-sonnet-4-5-20250929">>, maps:get(name, M2)),
    ?assertEqual(200000, maps:get(context_length, M2)),
    ?assertEqual(<<"claude">>, maps:get(family, M2)).

list_models_third_model_is_haiku_test() ->
    {ok, [_, _, M3]} = anthropic_provider:list_models(#{}),
    ?assertEqual(<<"claude-haiku-3-5-20241022">>, maps:get(name, M3)),
    ?assertEqual(200000, maps:get(context_length, M3)),
    ?assertEqual(<<"claude">>, maps:get(family, M3)).

list_models_all_have_api_format_test() ->
    {ok, Models} = anthropic_provider:list_models(#{}),
    lists:foreach(fun(M) ->
        ?assertEqual(<<"api">>, maps:get(format, M))
    end, Models).

list_models_ignores_config_test() ->
    %% Config is irrelevant for hardcoded models
    {ok, Models1} = anthropic_provider:list_models(#{}),
    {ok, Models2} = anthropic_provider:list_models(#{api_key => <<"sk-test">>}),
    ?assertEqual(Models1, Models2).
