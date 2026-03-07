%%% @doc Tests for evoq behaviour refactoring.
%%%
%%% Verifies that all refactored modules correctly implement
%%% evoq_event_handler callbacks:
%%% - interested_in/0 returns correct event types
%%% - init/1 returns {ok, State}
%%% - handle_event/4 processes events correctly
%%%
%%% These are unit tests — no gen_server, no stores, no subscriptions.
%%% We call the callback functions directly.
-module(evoq_behaviour_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% PG Emitter Tests
%%====================================================================

pg_emitter_interested_in_test_() ->
    PgEmitters = [
        {license_bought_v1_to_pg, <<"license_bought_v1">>},
        {license_revoked_v1_to_pg, <<"license_revoked_v1">>},
        {license_archived_v1_to_pg, <<"license_archived_v1">>},
        {license_initiated_v1_to_pg, <<"license_initiated_v1">>},
        {license_announced_v1_to_pg, <<"license_announced_v1">>},
        {license_published_v1_to_pg, <<"license_published_v1">>},
        {license_retracted_v1_to_pg, <<"license_retracted_v1">>},
        {entry_registered_v1_to_pg, <<"entry_registered_v1">>},
        {entry_unregistered_v1_to_pg, <<"entry_unregistered_v1">>},
        {launcher_reorganized_v1_to_pg, <<"launcher_reorganized_v1">>},
        {plugin_installed_v1_to_pg, <<"plugin_installed_v1">>},
        {plugin_removed_v1_to_pg, <<"plugin_removed_v1">>},
        {plugin_upgraded_v1_to_pg, <<"plugin_upgraded_v1">>},
        {plugin_execution_started_v1_to_pg, <<"plugin_execution_started_v1">>},
        {plugin_execution_stopped_v1_to_pg, <<"plugin_execution_stopped_v1">>},
        {container_confirmed_up_v1_to_pg, <<"container_confirmed_up_v1">>},
        {container_confirmed_down_v1_to_pg, <<"container_confirmed_down_v1">>},
        {oci_pull_started_v1_to_pg, <<"oci_pull_started_v1">>},
        {oci_pull_completed_v1_to_pg, <<"oci_pull_completed_v1">>},
        {oci_pull_cancelled_v1_to_pg, <<"oci_pull_cancelled_v1">>}
    ],
    [?_assertEqual([EventType], Mod:interested_in())
     || {Mod, EventType} <- PgEmitters].

pg_emitter_init_test_() ->
    Mods = [license_bought_v1_to_pg, entry_registered_v1_to_pg,
            plugin_installed_v1_to_pg, oci_pull_started_v1_to_pg],
    [?_assertMatch({ok, _}, Mod:init(#{})) || Mod <- Mods].

pg_emitter_handle_event_broadcasts_test() ->
    %% Start pg scope if not running
    ensure_pg(),
    Group = license_bought_v1,
    %% Join the pg group so we can receive the broadcast
    ok = pg:join(pg, Group, self()),
    Event = #{
        event_type => <<"license_bought_v1">>,
        event_id => <<"evt-1">>,
        stream_id => <<"license-123">>,
        version => 0,
        data => #{license_id => <<"lic-1">>},
        tags => undefined,
        timestamp => 0,
        epoch_us => 0
    },
    {ok, State} = license_bought_v1_to_pg:init(#{}),
    {ok, _NewState} = license_bought_v1_to_pg:handle_event(
        <<"license_bought_v1">>, Event, #{}, State),
    %% Verify we received the broadcast
    receive
        {Group, ReceivedEvent} ->
            ?assertEqual(Event, ReceivedEvent)
    after 100 ->
        ?assert(false, "Did not receive pg broadcast")
    end,
    pg:leave(pg, Group, self()).

%%====================================================================
%% Mesh Emitter Tests
%%====================================================================

mesh_emitter_interested_in_test_() ->
    MeshEmitters = [
        {license_published_v1_to_mesh, <<"license_published_v1">>}
    ],
    [?_assertEqual([EventType], Mod:interested_in())
     || {Mod, EventType} <- MeshEmitters].

mesh_emitter_init_test_() ->
    [?_assertMatch({ok, _}, license_published_v1_to_mesh:init(#{}))].

%%====================================================================
%% Projection Tests (license domain)
%%====================================================================

license_projection_interested_in_test_() ->
    Projections = [
        {license_bought_v1_to_licenses, <<"license_bought_v1">>},
        {license_revoked_v1_to_licenses, <<"license_revoked_v1">>},
        {license_archived_v1_to_licenses, <<"license_archived_v1">>},
        {license_initiated_v1_to_catalog, <<"license_initiated_v1">>},
        {license_announced_v1_to_catalog, <<"license_announced_v1">>},
        {license_published_v1_to_catalog, <<"license_published_v1">>},
        {license_amended_v1_to_catalog, <<"license_amended_v1">>},
        {license_retracted_v1_to_catalog, <<"license_retracted_v1">>},
        {plugin_installed_v1_to_licenses, <<"plugin_installed_v1">>},
        {plugin_removed_v1_to_licenses, <<"plugin_removed_v1">>},
        {plugin_upgraded_v1_to_licenses, <<"plugin_upgraded_v1">>}
    ],
    [?_assertEqual([EventType], Mod:interested_in())
     || {Mod, EventType} <- Projections].

%%====================================================================
%% Projection Tests (plugin domain)
%%====================================================================

plugin_projection_interested_in_test_() ->
    Projections = [
        {plugin_installed_v1_to_plugins, <<"plugin_installed_v1">>},
        {plugin_removed_v1_to_plugins, <<"plugin_removed_v1">>},
        {plugin_upgraded_v1_to_plugins, <<"plugin_upgraded_v1">>},
        {plugin_execution_started_v1_to_plugins, <<"plugin_execution_started_v1">>},
        {plugin_execution_stopped_v1_to_plugins, <<"plugin_execution_stopped_v1">>},
        {container_confirmed_up_v1_to_plugins, <<"container_confirmed_up_v1">>},
        {container_confirmed_down_v1_to_plugins, <<"container_confirmed_down_v1">>},
        {oci_pull_started_v1_to_plugins, <<"oci_pull_started_v1">>},
        {oci_pull_completed_v1_to_plugins, <<"oci_pull_completed_v1">>},
        {oci_pull_cancelled_v1_to_plugins, <<"oci_pull_cancelled_v1">>}
    ],
    [?_assertEqual([EventType], Mod:interested_in())
     || {Mod, EventType} <- Projections].

%%====================================================================
%% Projection Tests (launcher domain)
%%====================================================================

launcher_projection_interested_in_test_() ->
    Projections = [
        {entry_registered_v1_to_launcher, <<"entry_registered_v1">>},
        {entry_unregistered_v1_to_launcher, <<"entry_unregistered_v1">>},
        {launcher_initialized_v1_to_launcher, <<"launcher_initialized_v1">>},
        {launcher_reorganized_v1_to_launcher, <<"launcher_reorganized_v1">>}
    ],
    [?_assertEqual([EventType], Mod:interested_in())
     || {Mod, EventType} <- Projections].

%%====================================================================
%% Policy/PM Tests
%%====================================================================

policy_interested_in_test_() ->
    Policies = [
        {on_plugin_installed_register_entry, <<"plugin_installed_v1">>},
        {on_plugin_removed_unregister_entry, <<"plugin_removed_v1">>},
        {on_plugin_removed_deprovision_container, <<"plugin_removed_v1">>},
        {on_plugin_execution_stopped_stop_container, <<"plugin_execution_stopped_v1">>},
        {on_plugin_upgraded_update_container, <<"plugin_upgraded_v1">>}
    ],
    [?_assertEqual([EventType], Mod:interested_in())
     || {Mod, EventType} <- Policies].

policy_init_test_() ->
    Mods = [on_plugin_installed_register_entry,
            on_plugin_removed_unregister_entry,
            on_plugin_removed_deprovision_container,
            on_plugin_execution_stopped_stop_container,
            on_plugin_upgraded_update_container],
    [?_assertMatch({ok, _}, Mod:init(#{})) || Mod <- Mods].

%%====================================================================
%% Behaviour Contract Tests
%%====================================================================

%% Verify all event_handler modules export the required callbacks
event_handler_exports_test_() ->
    HandlerModules = pg_emitter_modules() ++ mesh_emitter_modules() ++
                     sqlite_projection_modules() ++ policy_modules(),
    lists:flatten([
        [?_assert(erlang:function_exported(Mod, interested_in, 0)),
         ?_assert(erlang:function_exported(Mod, init, 1)),
         ?_assert(erlang:function_exported(Mod, handle_event, 4))]
        || Mod <- HandlerModules
    ]).

%% Verify all evoq_projection modules export the required callbacks
projection_exports_test_() ->
    lists:flatten([
        [?_assert(erlang:function_exported(Mod, interested_in, 0)),
         ?_assert(erlang:function_exported(Mod, init, 1)),
         ?_assert(erlang:function_exported(Mod, project, 4))]
        || Mod <- ets_projection_modules()
    ]).

%% Verify no refactored modules still export gen_server callbacks
no_gen_server_exports_test_() ->
    AllModules = pg_emitter_modules() ++ mesh_emitter_modules() ++
                 sqlite_projection_modules() ++ ets_projection_modules() ++
                 policy_modules(),
    [?_assertNot(erlang:function_exported(Mod, handle_call, 3))
     || Mod <- AllModules].

%%====================================================================
%% Helpers
%%====================================================================

ensure_pg() ->
    case pg:start(pg) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.

pg_emitter_modules() ->
    [license_bought_v1_to_pg, license_revoked_v1_to_pg,
     license_archived_v1_to_pg, license_initiated_v1_to_pg,
     license_announced_v1_to_pg, license_published_v1_to_pg,
     license_retracted_v1_to_pg,
     entry_registered_v1_to_pg, entry_unregistered_v1_to_pg,
     launcher_reorganized_v1_to_pg,
     plugin_installed_v1_to_pg, plugin_removed_v1_to_pg,
     plugin_upgraded_v1_to_pg,
     plugin_execution_started_v1_to_pg, plugin_execution_stopped_v1_to_pg,
     container_confirmed_up_v1_to_pg, container_confirmed_down_v1_to_pg,
     oci_pull_started_v1_to_pg, oci_pull_completed_v1_to_pg,
     oci_pull_cancelled_v1_to_pg].

mesh_emitter_modules() ->
    [license_published_v1_to_mesh].

%% No more SQLite-backed projections — all converted to evoq_projection
sqlite_projection_modules() ->
    [].

%% ETS-backed projections (evoq_projection, converted)
ets_projection_modules() ->
    %% Plugin projections
    [plugin_installed_v1_to_plugins,
     plugin_removed_v1_to_plugins,
     plugin_upgraded_v1_to_plugins,
     plugin_execution_started_v1_to_plugins,
     plugin_execution_stopped_v1_to_plugins,
     container_confirmed_up_v1_to_plugins,
     container_confirmed_down_v1_to_plugins,
     oci_pull_started_v1_to_plugins,
     oci_pull_completed_v1_to_plugins,
     oci_pull_cancelled_v1_to_plugins,
     %% License projections
     license_bought_v1_to_licenses,
     license_revoked_v1_to_licenses,
     license_archived_v1_to_licenses,
     license_initiated_v1_to_catalog,
     license_announced_v1_to_catalog,
     license_published_v1_to_catalog,
     license_amended_v1_to_catalog,
     license_retracted_v1_to_catalog,
     plugin_installed_v1_to_licenses,
     plugin_removed_v1_to_licenses,
     plugin_upgraded_v1_to_licenses,
     %% Launcher projections
     entry_registered_v1_to_launcher,
     entry_unregistered_v1_to_launcher,
     launcher_initialized_v1_to_launcher,
     launcher_reorganized_v1_to_launcher].

policy_modules() ->
    [on_plugin_installed_register_entry,
     on_plugin_removed_unregister_entry,
     on_plugin_removed_deprovision_container,
     on_plugin_execution_stopped_stop_container,
     on_plugin_upgraded_update_container].
