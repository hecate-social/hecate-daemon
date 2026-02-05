%%% @doc Tests for manage_providers module
-module(manage_providers_test).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Public API export verification
%% ===================================================================

exports_start_link_test() ->
    Exports = manage_providers:module_info(exports),
    ?assert(lists:member({start_link, 0}, Exports)).

exports_list_test() ->
    Exports = manage_providers:module_info(exports),
    ?assert(lists:member({list, 0}, Exports)).

exports_add_test() ->
    Exports = manage_providers:module_info(exports),
    ?assert(lists:member({add, 3}, Exports)).

exports_remove_test() ->
    Exports = manage_providers:module_info(exports),
    ?assert(lists:member({remove, 1}, Exports)).

exports_provider_for_model_test() ->
    Exports = manage_providers:module_info(exports),
    ?assert(lists:member({provider_for_model, 1}, Exports)).

exports_refresh_models_test() ->
    Exports = manage_providers:module_info(exports),
    ?assert(lists:member({refresh_models, 0}, Exports)).

%% ===================================================================
%% gen_server callback export verification
%% ===================================================================

exports_init_test() ->
    Exports = manage_providers:module_info(exports),
    ?assert(lists:member({init, 1}, Exports)).

exports_handle_call_test() ->
    Exports = manage_providers:module_info(exports),
    ?assert(lists:member({handle_call, 3}, Exports)).

exports_handle_cast_test() ->
    Exports = manage_providers:module_info(exports),
    ?assert(lists:member({handle_cast, 2}, Exports)).

exports_handle_info_test() ->
    Exports = manage_providers:module_info(exports),
    ?assert(lists:member({handle_info, 2}, Exports)).

exports_terminate_test() ->
    Exports = manage_providers:module_info(exports),
    ?assert(lists:member({terminate, 2}, Exports)).

%% ===================================================================
%% Behaviour verification
%% ===================================================================

implements_gen_server_behaviour_test() ->
    Attrs = manage_providers:module_info(attributes),
    Behaviours = proplists:get_value(behaviour, Attrs, []),
    ?assert(lists:member(gen_server, Behaviours)).
