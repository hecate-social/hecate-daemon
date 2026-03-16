%%% @doc Tests for plugin_lifecycle_to_plugins merged projection.
%%%
%%% Verifies that the ETS read model is updated correctly for in-VM plugins.
%%% Specifically catches the name corruption bug: the `name` field in the
%%% read model must match what the install command provides (clean manifest
%%% name, no org prefix).
-module(plugin_lifecycle_to_plugins_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("guide_plugin_lifecycle/include/plugin_status.hrl").

-define(TABLE, plugins).
-define(PLUGIN_ID, <<"hecate-apps/hecate-app-scribe">>).
-define(PLUGIN_NAME, <<"hecate-app-scribe">>).
-define(CALLBACK_MODULE, <<"app_scribe">>).

%% -- Setup / Teardown --

setup() ->
    %% Create a fresh read model for each test
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    RM.

cleanup(RM) ->
    %% evoq_read_model_ets creates a named table — delete it
    catch ets:delete(?TABLE),
    RM.

%% -- Helpers --

make_installed_event() ->
    #{
        event_type        => <<"plugin_installed_v1">>,
        plugin_id         => ?PLUGIN_ID,
        name              => ?PLUGIN_NAME,
        display_name      => <<"Scribe">>,
        plugin_type       => <<"in_vm">>,
        callback_module   => ?CALLBACK_MODULE,
        package_url       => <<"https://example.com/pkg.tar.gz">>,
        installed_version => <<"0.1.5">>,
        license_id        => <<"lic-123">>,
        icon              => <<"pencil">>,
        group_name        => <<"OFFICE">>,
        group_icon        => <<"briefcase">>,
        installed_at      => erlang:system_time(millisecond)
    }.

make_execution_requested_event() ->
    #{
        event_type      => <<"plugin_execution_requested_v1">>,
        plugin_id       => ?PLUGIN_ID,
        plugin_type     => <<"in_vm">>,
        callback_module => ?CALLBACK_MODULE,
        requested_at    => erlang:system_time(millisecond)
    }.

make_load_confirmed_event() ->
    #{
        event_type => <<"plugin_load_confirmed_v1">>,
        plugin_id  => ?PLUGIN_ID
    }.

make_termination_requested_event() ->
    #{
        event_type   => <<"plugin_termination_requested_v1">>,
        plugin_id    => ?PLUGIN_ID,
        plugin_type  => <<"in_vm">>,
        requested_at => erlang:system_time(millisecond)
    }.

make_unload_confirmed_event() ->
    #{
        event_type => <<"plugin_unload_confirmed_v1">>,
        plugin_id  => ?PLUGIN_ID
    }.

wrap_event(Data) ->
    #{data => Data, event_type => maps:get(event_type, Data)}.

project(Data, State, RM) ->
    plugin_lifecycle_to_plugins:project(wrap_event(Data), #{}, State, RM).

%% ===================================================================
%% Name Integrity Tests
%% ===================================================================

%% CRITICAL: The name in the read model must be the clean name from the
%% install command, NOT the plugin_id with org prefix.
name_has_no_org_prefix_test() ->
    RM = setup(),
    try
        {ok, S1, RM1} = project(make_installed_event(), #{}, RM),
        {ok, Plugin} = evoq_read_model:get(?PLUGIN_ID, RM1),
        Name = maps:get(name, Plugin),
        ?assertEqual(?PLUGIN_NAME, Name),
        ?assertEqual(nomatch, binary:match(Name, <<"/">>)),
        _ = S1
    after
        cleanup(RM)
    end.

display_name_preserved_test() ->
    RM = setup(),
    try
        {ok, _S, RM1} = project(make_installed_event(), #{}, RM),
        {ok, Plugin} = evoq_read_model:get(?PLUGIN_ID, RM1),
        ?assertEqual(<<"Scribe">>, maps:get(display_name, Plugin))
    after
        cleanup(RM)
    end.

%% ===================================================================
%% Status Label Transitions (in-VM path)
%% ===================================================================

installed_status_label_test() ->
    RM = setup(),
    try
        {ok, _S, RM1} = project(make_installed_event(), #{}, RM),
        {ok, Plugin} = evoq_read_model:get(?PLUGIN_ID, RM1),
        ?assertEqual(<<"Installed">>, maps:get(status_label, Plugin)),
        ?assertEqual(?PLG_INSTALLED, maps:get(status, Plugin))
    after
        cleanup(RM)
    end.

execution_requested_sets_starting_test() ->
    RM = setup(),
    try
        {ok, S1, RM1} = project(make_installed_event(), #{}, RM),
        {ok, _S2, RM2} = project(make_execution_requested_event(), S1, RM1),
        {ok, Plugin} = evoq_read_model:get(?PLUGIN_ID, RM2),
        ?assertEqual(<<"Starting">>, maps:get(status_label, Plugin)),
        ?assertNotEqual(0, maps:get(status, Plugin) band ?PLG_RUNNING)
    after
        cleanup(RM)
    end.

%% CRITICAL: After load confirmed, status_label must be "Running".
%% This is what the frontend checks to bring the plugin online.
load_confirmed_sets_running_test() ->
    RM = setup(),
    try
        {ok, S1, RM1} = project(make_installed_event(), #{}, RM),
        {ok, S2, RM2} = project(make_execution_requested_event(), S1, RM1),
        {ok, _S3, RM3} = project(make_load_confirmed_event(), S2, RM2),
        {ok, Plugin} = evoq_read_model:get(?PLUGIN_ID, RM3),
        ?assertEqual(<<"Running">>, maps:get(status_label, Plugin))
    after
        cleanup(RM)
    end.

termination_requested_sets_stopped_test() ->
    RM = setup(),
    try
        {ok, S1, RM1} = project(make_installed_event(), #{}, RM),
        {ok, S2, RM2} = project(make_execution_requested_event(), S1, RM1),
        {ok, S3, RM3} = project(make_load_confirmed_event(), S2, RM2),
        {ok, _S4, RM4} = project(make_termination_requested_event(), S3, RM3),
        {ok, Plugin} = evoq_read_model:get(?PLUGIN_ID, RM4),
        ?assertEqual(<<"Stopped">>, maps:get(status_label, Plugin))
    after
        cleanup(RM)
    end.

unload_confirmed_sets_stopped_test() ->
    RM = setup(),
    try
        {ok, S1, RM1} = project(make_installed_event(), #{}, RM),
        {ok, S2, RM2} = project(make_execution_requested_event(), S1, RM1),
        {ok, S3, RM3} = project(make_load_confirmed_event(), S2, RM2),
        {ok, S4, RM4} = project(make_termination_requested_event(), S3, RM3),
        {ok, _S5, RM5} = project(make_unload_confirmed_event(), S4, RM4),
        {ok, Plugin} = evoq_read_model:get(?PLUGIN_ID, RM5),
        ?assertEqual(<<"Stopped">>, maps:get(status_label, Plugin))
    after
        cleanup(RM)
    end.

%% ===================================================================
%% In-VM Specific Fields
%% ===================================================================

in_vm_fields_stored_test() ->
    RM = setup(),
    try
        {ok, _S, RM1} = project(make_installed_event(), #{}, RM),
        {ok, Plugin} = evoq_read_model:get(?PLUGIN_ID, RM1),
        ?assertEqual(<<"in_vm">>, maps:get(plugin_type, Plugin)),
        ?assertEqual(?CALLBACK_MODULE, maps:get(callback_module, Plugin)),
        ?assertEqual(<<"https://example.com/pkg.tar.gz">>, maps:get(package_url, Plugin))
    after
        cleanup(RM)
    end.

%% ===================================================================
%% Missing Event (not_found handling)
%% ===================================================================

execution_before_install_skips_test() ->
    RM = setup(),
    try
        {skip, _S, _RM1} = project(make_execution_requested_event(), #{}, RM)
    after
        cleanup(RM)
    end.
