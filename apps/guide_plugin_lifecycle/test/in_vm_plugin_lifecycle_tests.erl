%%% @doc Tests for the in-VM plugin lifecycle through the aggregate.
%%%
%%% Covers the in-VM path:
%%%   install -> activate -> confirm_loaded -> deactivate -> confirm_unloaded
%%%
%%% NOTE: extract_plugin_package is skipped in aggregate tests because the
%%% handler downloads a tarball (side effect). Extract is tested separately.
%%%
%%% Verifies:
%%%   - Name field integrity (no org prefix corruption)
%%%   - Status transitions via bit flags
%%%   - Event field completeness (all fields needed by downstream PMs)
%%%   - Callback module carried through the lifecycle
-module(in_vm_plugin_lifecycle_tests).

-include_lib("eunit/include/eunit.hrl").
-include("plugin_status.hrl").
-include("plugin_state.hrl").

%% -- Test Data --

-define(PLUGIN_ID, <<"hecate-apps/hecate-app-scribe">>).
-define(PLUGIN_NAME, <<"hecate-app-scribe">>).
-define(VERSION, <<"0.1.5">>).
-define(LICENSE_ID, <<"lic-abc-123">>).
-define(CALLBACK_MODULE, <<"app_scribe">>).
-define(PACKAGE_URL, <<"https://github.com/hecate-apps/hecate-app-scribe/releases/download/v0.1.5/hecate-app-scribe.tar.gz">>).

%% -- Helpers --

fresh_state() ->
    plugin_aggregate:initial_state().

make_in_vm_install_payload() ->
    #{
        <<"command_type">>      => <<"install_plugin">>,
        <<"plugin_id">>         => ?PLUGIN_ID,
        <<"name">>              => ?PLUGIN_NAME,
        <<"plugin_type">>       => <<"in_vm">>,
        <<"callback_module">>   => ?CALLBACK_MODULE,
        <<"package_url">>       => ?PACKAGE_URL,
        <<"installed_version">> => ?VERSION,
        <<"license_id">>        => ?LICENSE_ID,
        <<"icon">>              => <<"pencil">>,
        <<"group_name">>        => <<"OFFICE">>,
        <<"group_icon">>        => <<"briefcase">>
    }.

make_activate_payload() ->
    #{
        <<"command_type">>      => <<"activate_plugin">>,
        <<"plugin_id">>         => ?PLUGIN_ID,
        <<"callback_module">>   => ?CALLBACK_MODULE
    }.

make_confirm_loaded_payload() ->
    #{
        <<"command_type">> => <<"confirm_plugin_loaded">>,
        <<"plugin_id">>    => ?PLUGIN_ID
    }.

make_deactivate_payload() ->
    #{
        <<"command_type">> => <<"deactivate_plugin">>,
        <<"plugin_id">>    => ?PLUGIN_ID
    }.

make_confirm_unloaded_payload() ->
    #{
        <<"command_type">> => <<"confirm_plugin_unloaded">>,
        <<"plugin_id">>    => ?PLUGIN_ID
    }.

execute_and_apply(State, Payload) ->
    case plugin_aggregate:execute(State, Payload) of
        {ok, EventMaps} ->
            NewState = lists:foldl(
                fun(E, S) -> plugin_aggregate:apply(S, E) end,
                State, EventMaps),
            {ok, NewState, EventMaps};
        {error, _} = Err ->
            Err
    end.

installed_state() ->
    {ok, S, _} = execute_and_apply(fresh_state(), make_in_vm_install_payload()),
    S.

activated_state() ->
    {ok, S, _} = execute_and_apply(installed_state(), make_activate_payload()),
    S.

loaded_state() ->
    {ok, S, _} = execute_and_apply(activated_state(), make_confirm_loaded_payload()),
    S.

%% ===================================================================
%% Install Tests
%% ===================================================================

install_in_vm_plugin_test() ->
    {ok, S, _} = execute_and_apply(fresh_state(), make_in_vm_install_payload()),
    ?assertNotEqual(0, S#plugin_state.status band ?PLG_INSTALLED),
    ?assertEqual(<<"in_vm">>, S#plugin_state.plugin_type),
    ?assertEqual(?CALLBACK_MODULE, S#plugin_state.callback_module),
    ?assertEqual(?PACKAGE_URL, S#plugin_state.package_url).

%% CRITICAL: The name in the event must be the clean plugin name,
%% not the composite plugin_id with org prefix.
install_event_name_has_no_org_prefix_test() ->
    {ok, _S, [Event]} = execute_and_apply(fresh_state(), make_in_vm_install_payload()),
    Name = maps:get(name, Event),
    ?assertEqual(?PLUGIN_NAME, Name),
    ?assertEqual(nomatch, binary:match(Name, <<"/">>)).

install_event_carries_in_vm_fields_test() ->
    {ok, _S, [Event]} = execute_and_apply(fresh_state(), make_in_vm_install_payload()),
    ?assertEqual(<<"in_vm">>, maps:get(plugin_type, Event)),
    ?assertEqual(?CALLBACK_MODULE, maps:get(callback_module, Event)),
    ?assertEqual(?PACKAGE_URL, maps:get(package_url, Event)).

%% ===================================================================
%% Activate Tests (skipping extract — it has side effects)
%% ===================================================================

activate_after_install_test() ->
    {ok, S, [Event]} = execute_and_apply(installed_state(), make_activate_payload()),
    ?assertEqual(<<"plugin_activated_v1">>, maps:get(event_type, Event)),
    ?assertNotEqual(0, S#plugin_state.status band ?PLG_ACTIVATED),
    ?assertNotEqual(undefined, S#plugin_state.activated_at).

%% The activate event MUST carry callback_module — the load PM needs it.
activate_event_carries_callback_module_test() ->
    {ok, _S, [Event]} = execute_and_apply(installed_state(), make_activate_payload()),
    ?assertEqual(?CALLBACK_MODULE, maps:get(callback_module, Event)).

%% The activate event must carry plugin_id for the load PM.
activate_event_carries_plugin_id_test() ->
    {ok, _S, [Event]} = execute_and_apply(installed_state(), make_activate_payload()),
    ?assertEqual(?PLUGIN_ID, maps:get(plugin_id, Event)).

cannot_activate_twice_test() ->
    Result = plugin_aggregate:execute(activated_state(), make_activate_payload()),
    ?assertEqual({error, plugin_already_activated}, Result).

%% ===================================================================
%% Confirm Loaded Tests
%% ===================================================================

confirm_loaded_after_activate_test() ->
    {ok, _S, [Event]} = execute_and_apply(activated_state(), make_confirm_loaded_payload()),
    ?assertEqual(<<"plugin_load_confirmed_v1">>, maps:get(event_type, Event)).

%% ===================================================================
%% Deactivate + Confirm Unloaded Tests
%% ===================================================================

deactivate_after_loaded_test() ->
    {ok, S, [Event]} = execute_and_apply(loaded_state(), make_deactivate_payload()),
    ?assertEqual(<<"plugin_deactivated_v1">>, maps:get(event_type, Event)),
    ?assertNotEqual(0, S#plugin_state.status band ?PLG_DEACTIVATED),
    %% ACTIVATED flag must be cleared
    ?assertEqual(0, S#plugin_state.status band ?PLG_ACTIVATED).

confirm_unloaded_after_deactivate_test() ->
    {ok, S1, _} = execute_and_apply(loaded_state(), make_deactivate_payload()),
    {ok, _S2, [Event]} = execute_and_apply(S1, make_confirm_unloaded_payload()),
    ?assertEqual(<<"plugin_unload_confirmed_v1">>, maps:get(event_type, Event)).

cannot_deactivate_when_not_activated_test() ->
    Result = plugin_aggregate:execute(installed_state(), make_deactivate_payload()),
    ?assertEqual({error, plugin_not_activated}, Result).

%% ===================================================================
%% Full Lifecycle Test
%% ===================================================================

full_in_vm_lifecycle_test() ->
    S0 = fresh_state(),
    {ok, S1, _} = execute_and_apply(S0, make_in_vm_install_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_activate_payload()),
    {ok, S3, _} = execute_and_apply(S2, make_confirm_loaded_payload()),

    %% At this point: INSTALLED + ACTIVATED, name is clean
    ?assertNotEqual(0, S3#plugin_state.status band ?PLG_INSTALLED),
    ?assertNotEqual(0, S3#plugin_state.status band ?PLG_ACTIVATED),
    ?assertEqual(?PLUGIN_NAME, S3#plugin_state.name),
    ?assertEqual(?CALLBACK_MODULE, S3#plugin_state.callback_module),

    %% Deactivate + unload
    {ok, S4, _} = execute_and_apply(S3, make_deactivate_payload()),
    {ok, S5, _} = execute_and_apply(S4, make_confirm_unloaded_payload()),

    ?assertNotEqual(0, S5#plugin_state.status band ?PLG_DEACTIVATED),
    ?assertEqual(0, S5#plugin_state.status band ?PLG_ACTIVATED).

%% ===================================================================
%% Guard: start_plugin_execution rejected for activated in-VM plugins
%% ===================================================================

start_execution_rejected_when_activated_test() ->
    %% After activate, start_plugin_execution must be rejected
    Result = plugin_aggregate:execute(activated_state(), make_start_execution_payload()),
    ?assertEqual({error, plugin_already_running}, Result).

start_execution_rejected_when_loaded_test() ->
    %% After confirm_loaded, start_plugin_execution must still be rejected
    Result = plugin_aggregate:execute(loaded_state(), make_start_execution_payload()),
    ?assertEqual({error, plugin_already_running}, Result).

make_start_execution_payload() ->
    #{
        <<"command_type">> => <<"start_plugin_execution">>,
        <<"plugin_id">>    => ?PLUGIN_ID
    }.
