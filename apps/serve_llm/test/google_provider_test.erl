%%% @doc Tests for google_provider module
-module(google_provider_test).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Module export verification
%% ===================================================================

exports_list_models_test() ->
    Exports = google_provider:module_info(exports),
    ?assert(lists:member({list_models, 1}, Exports)).

exports_chat_test() ->
    Exports = google_provider:module_info(exports),
    ?assert(lists:member({chat, 4}, Exports)).

exports_chat_stream_test() ->
    Exports = google_provider:module_info(exports),
    ?assert(lists:member({chat_stream, 6}, Exports)).

exports_health_test() ->
    Exports = google_provider:module_info(exports),
    ?assert(lists:member({health, 1}, Exports)).

%% ===================================================================
%% Behaviour verification
%% ===================================================================

implements_llm_provider_behaviour_test() ->
    Attrs = google_provider:module_info(attributes),
    Behaviours = proplists:get_value(behaviour, Attrs, []),
    ?assert(lists:member(llm_provider, Behaviours)).
