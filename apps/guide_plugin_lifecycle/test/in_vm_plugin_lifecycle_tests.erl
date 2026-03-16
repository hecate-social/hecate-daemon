%%% @doc Tests for the in-VM plugin lifecycle through the aggregate.
%%%
%%% Covers the in-VM path:
%%%   install -> request_execution -> confirm_loaded -> request_termination -> confirm_unloaded
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
    plugin_state:new(<<>>).

make_in_vm_install_payload() ->
    #{
        command_type      => <<"install_plugin">>,
        plugin_id         => ?PLUGIN_ID,
        name              => ?PLUGIN_NAME,
        plugin_type       => <<"in_vm">>,
        callback_module   => ?CALLBACK_MODULE,
        package_url       => ?PACKAGE_URL,
        installed_version => ?VERSION,
        license_id        => ?LICENSE_ID,
        icon              => <<"pencil">>,
        group_name        => <<"OFFICE">>,
        group_icon        => <<"briefcase">>
    }.

make_request_execution_payload() ->
    #{
        command_type => <<"request_plugin_execution">>,
        plugin_id    => ?PLUGIN_ID
    }.

make_confirm_loaded_payload() ->
    #{
        command_type => <<"confirm_plugin_loaded">>,
        plugin_id    => ?PLUGIN_ID
    }.

make_request_termination_payload() ->
    #{
        command_type => <<"request_plugin_termination">>,
        plugin_id    => ?PLUGIN_ID
    }.

make_confirm_unloaded_payload() ->
    #{
        command_type => <<"confirm_plugin_unloaded">>,
        plugin_id    => ?PLUGIN_ID
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

running_state() ->
    {ok, S, _} = execute_and_apply(installed_state(), make_request_execution_payload()),
    S.

loaded_state() ->
    {ok, S, _} = execute_and_apply(running_state(), make_confirm_loaded_payload()),
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
%% Request Execution Tests
%% ===================================================================

request_execution_after_install_test() ->
    {ok, S, [Event]} = execute_and_apply(installed_state(), make_request_execution_payload()),
    ?assertEqual(<<"plugin_execution_requested_v1">>, maps:get(event_type, Event)),
    ?assertNotEqual(0, S#plugin_state.status band ?PLG_RUNNING).

%% The execution event MUST carry callback_module — the in-VM PM needs it.
execution_event_carries_callback_module_test() ->
    {ok, _S, [Event]} = execute_and_apply(installed_state(), make_request_execution_payload()),
    ?assertEqual(?CALLBACK_MODULE, maps:get(callback_module, Event)).

%% The execution event must carry plugin_id.
execution_event_carries_plugin_id_test() ->
    {ok, _S, [Event]} = execute_and_apply(installed_state(), make_request_execution_payload()),
    ?assertEqual(?PLUGIN_ID, maps:get(plugin_id, Event)).

%% The execution event must carry plugin_type for PM filtering.
execution_event_carries_plugin_type_test() ->
    {ok, _S, [Event]} = execute_and_apply(installed_state(), make_request_execution_payload()),
    ?assertEqual(<<"in_vm">>, maps:get(plugin_type, Event)).

cannot_request_execution_twice_test() ->
    Result = plugin_aggregate:execute(running_state(), make_request_execution_payload()),
    ?assertEqual({error, plugin_already_running}, Result).

%% ===================================================================
%% Confirm Loaded Tests
%% ===================================================================

confirm_loaded_after_execution_test() ->
    {ok, _S, [Event]} = execute_and_apply(running_state(), make_confirm_loaded_payload()),
    ?assertEqual(<<"plugin_load_confirmed_v1">>, maps:get(event_type, Event)).

%% ===================================================================
%% Request Termination + Confirm Unloaded Tests
%% ===================================================================

request_termination_after_running_test() ->
    {ok, S, [Event]} = execute_and_apply(running_state(), make_request_termination_payload()),
    ?assertEqual(<<"plugin_termination_requested_v1">>, maps:get(event_type, Event)),
    ?assertNotEqual(0, S#plugin_state.status band ?PLG_STOPPED),
    %% RUNNING flag must be cleared
    ?assertEqual(0, S#plugin_state.status band ?PLG_RUNNING).

confirm_unloaded_after_termination_test() ->
    {ok, S1, _} = execute_and_apply(running_state(), make_request_termination_payload()),
    {ok, _S2, [Event]} = execute_and_apply(S1, make_confirm_unloaded_payload()),
    ?assertEqual(<<"plugin_unload_confirmed_v1">>, maps:get(event_type, Event)).

%% ===================================================================
%% Full Lifecycle Test
%% ===================================================================

full_in_vm_lifecycle_test() ->
    S0 = fresh_state(),
    {ok, S1, _} = execute_and_apply(S0, make_in_vm_install_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_request_execution_payload()),
    {ok, S3, _} = execute_and_apply(S2, make_confirm_loaded_payload()),

    %% At this point: INSTALLED + RUNNING, name is clean
    ?assertNotEqual(0, S3#plugin_state.status band ?PLG_INSTALLED),
    ?assertNotEqual(0, S3#plugin_state.status band ?PLG_RUNNING),
    ?assertEqual(?PLUGIN_NAME, S3#plugin_state.name),
    ?assertEqual(?CALLBACK_MODULE, S3#plugin_state.callback_module),

    %% Terminate + unload
    {ok, S4, _} = execute_and_apply(S3, make_request_termination_payload()),
    {ok, S5, _} = execute_and_apply(S4, make_confirm_unloaded_payload()),

    ?assertNotEqual(0, S5#plugin_state.status band ?PLG_STOPPED),
    ?assertEqual(0, S5#plugin_state.status band ?PLG_RUNNING).

%% ===================================================================
%% Guard: request_plugin_execution rejected when already running
%% ===================================================================

start_execution_rejected_when_running_test() ->
    Result = plugin_aggregate:execute(running_state(), make_request_execution_payload()),
    ?assertEqual({error, plugin_already_running}, Result).

start_execution_rejected_when_loaded_test() ->
    %% After confirm_loaded, request_plugin_execution must still be rejected
    Result = plugin_aggregate:execute(loaded_state(), make_request_execution_payload()),
    ?assertEqual({error, plugin_already_running}, Result).
