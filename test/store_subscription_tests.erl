%%% @doc Tests for evoq_store_subscription integration.
%%%
%%% Verifies that evoq 1.6.0 store subscription bridge and
%%% event type registry listener APIs are available.
-module(store_subscription_tests).

-include_lib("eunit/include/eunit.hrl").

store_subscription_module_available_test() ->
    {module, _} = code:ensure_loaded(evoq_store_subscription),
    ?assert(erlang:function_exported(evoq_store_subscription, start_link, 1)),
    ?assert(erlang:function_exported(evoq_store_subscription, start_link, 2)).

event_conversion_available_test() ->
    {module, _} = code:ensure_loaded(evoq_store_subscription),
    ?assert(erlang:function_exported(evoq_store_subscription, evoq_event_to_routable, 1)).

event_type_registry_listener_api_test() ->
    {module, _} = code:ensure_loaded(evoq_event_type_registry),
    ?assert(erlang:function_exported(evoq_event_type_registry, register_listener, 1)),
    ?assert(erlang:function_exported(evoq_event_type_registry, unregister_listener, 1)).
