%%% @doc Tests for evoq behaviour compliance.
%%%
%%% Verifies that all modules implementing evoq behaviours
%%% correctly export the required callbacks:
%%% - evoq_event_handler: interested_in/0, init/1, handle_event/4
%%% - evoq_projection: interested_in/0, init/1, project/4
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
        %% Consumer license domain
        {license_initiated_v1_to_pg, <<"license_initiated_v1">>},
        {offering_terms_accepted_v1_to_pg, <<"offering_terms_accepted_v1">>},
        {offering_terms_rejected_v1_to_pg, <<"offering_terms_rejected_v1">>},
        {license_bought_v1_to_pg, <<"license_bought_v1">>},
        {license_abandoned_v1_to_pg, <<"license_abandoned_v1">>},
        {license_granted_v1_to_pg, <<"license_granted_v1">>},
        {license_expired_v1_to_pg, <<"license_expired_v1">>},
        {license_renewed_v1_to_pg, <<"license_renewed_v1">>},
        {license_revoked_v1_to_pg, <<"license_revoked_v1">>},
        {license_archived_v1_to_pg, <<"license_archived_v1">>},
        %% Author offering domain
        {offering_initiated_v1_to_pg, <<"offering_initiated_v1">>},
        {offering_announced_v1_to_pg, <<"offering_announced_v1">>},
        {offering_published_v1_to_pg, <<"offering_published_v1">>},
        {offering_amended_v1_to_pg, <<"offering_amended_v1">>},
        {offering_retracted_v1_to_pg, <<"offering_retracted_v1">>},
        {offering_archived_v1_to_pg, <<"offering_archived_v1">>},
        {offering_drafted_v1_to_pg, <<"offering_drafted_v1">>},
        %% Launcher domain
        {entry_registered_v1_to_pg, <<"entry_registered_v1">>},
        {entry_unregistered_v1_to_pg, <<"entry_unregistered_v1">>},
        {launcher_reorganized_v1_to_pg, <<"launcher_reorganized_v1">>},
        %% Plugin domain
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
    Mods = [license_bought_v1_to_pg, license_initiated_v1_to_pg,
            offering_initiated_v1_to_pg, offering_published_v1_to_pg,
            entry_registered_v1_to_pg,
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
        {offering_published_v1_to_mesh, <<"offering_published_v1">>}
    ],
    [?_assertEqual([EventType], Mod:interested_in())
     || {Mod, EventType} <- MeshEmitters].

mesh_emitter_init_test_() ->
    [?_assertMatch({ok, _}, offering_published_v1_to_mesh:init(#{}))].

%%====================================================================
%% Projection Tests (consumer license domain)
%%====================================================================

license_projection_interested_in_test_() ->
    %% Merged lifecycle projection (all consumer license events)
    [?_assertEqual(
        [<<"license_initiated_v1">>,
         <<"offering_terms_accepted_v1">>,
         <<"offering_terms_rejected_v1">>,
         <<"license_bought_v1">>,
         <<"license_abandoned_v1">>,
         <<"license_granted_v1">>,
         <<"license_expired_v1">>,
         <<"license_renewed_v1">>,
         <<"license_revoked_v1">>,
         <<"license_archived_v1">>],
        license_lifecycle_to_licenses:interested_in())].

%%====================================================================
%% Projection Tests (author offering domain)
%%====================================================================

offering_projection_interested_in_test_() ->
    %% Merged lifecycle projection (all offering events)
    [?_assertEqual(
        [<<"offering_initiated_v1">>,
         <<"offering_announced_v1">>,
         <<"offering_published_v1">>,
         <<"offering_amended_v1">>,
         <<"offering_retracted_v1">>,
         <<"offering_archived_v1">>],
        offering_lifecycle_to_offerings:interested_in())].

%%====================================================================
%% Projection Tests (plugin domain)
%%====================================================================

plugin_projection_interested_in_test_() ->
    %% Merged lifecycle projection (all plugin events in single gen_server)
    [?_assertEqual(
        [<<"plugin_installed_v1">>, <<"plugin_upgraded_v1">>,
         <<"plugin_removed_v1">>, <<"plugin_execution_started_v1">>,
         <<"plugin_execution_stopped_v1">>, <<"container_confirmed_up_v1">>,
         <<"container_confirmed_down_v1">>, <<"oci_pull_started_v1">>,
         <<"oci_pull_cancelled_v1">>, <<"oci_pull_completed_v1">>],
        plugin_lifecycle_to_plugins:interested_in())].

%%====================================================================
%% Projection Tests (launcher domain)
%%====================================================================

launcher_projection_interested_in_test_() ->
    %% Merged lifecycle projection (all launcher events in single gen_server)
    [?_assertEqual(
        [<<"launcher_initialized_v1">>, <<"entry_registered_v1">>,
         <<"entry_unregistered_v1">>, <<"launcher_reorganized_v1">>],
        launcher_lifecycle_to_launcher:interested_in())].

%%====================================================================
%% Policy/PM Tests
%%====================================================================

policy_interested_in_test_() ->
    Policies = [
        %% Plugin domain PMs
        {on_plugin_installed_register_entry, <<"plugin_installed_v1">>},
        {on_plugin_removed_unregister_entry, <<"plugin_removed_v1">>},
        {on_plugin_removed_deprovision_container, <<"plugin_removed_v1">>},
        {on_plugin_execution_stopped_stop_container, <<"plugin_execution_stopped_v1">>},
        {on_plugin_upgraded_update_container, <<"plugin_upgraded_v1">>},
        %% Consumer license domain PMs
        {on_offering_terms_accepted_grant_license, <<"offering_terms_accepted_v1">>},
        {on_license_bought_grant_license, <<"license_bought_v1">>},
        {on_license_granted_install_plugin, <<"license_granted_v1">>},
        %% Cross-context PMs
        {on_offering_terms_accepted_initiate_procurement, <<"offering_terms_accepted_v1">>},
        {on_procurement_initiated_initiate_sale, <<"procurement_initiated_v1">>}
    ],
    [?_assertEqual([EventType], Mod:interested_in())
     || {Mod, EventType} <- Policies].

policy_init_test_() ->
    Mods = [on_plugin_installed_register_entry,
            on_plugin_removed_unregister_entry,
            on_plugin_removed_deprovision_container,
            on_plugin_execution_stopped_stop_container,
            on_plugin_upgraded_update_container,
            on_offering_terms_accepted_grant_license,
            on_license_bought_grant_license,
            on_license_granted_install_plugin,
            on_offering_terms_accepted_initiate_procurement,
            on_procurement_initiated_initiate_sale],
    [?_assertMatch({ok, _}, Mod:init(#{})) || Mod <- Mods].

%%====================================================================
%% Behaviour Contract Tests
%%====================================================================

%% Verify all event_handler modules export the required callbacks
event_handler_exports_test_() ->
    HandlerModules = pg_emitter_modules() ++ mesh_emitter_modules() ++
                     policy_modules(),
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
                 ets_projection_modules() ++ policy_modules(),
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
    %% Consumer license emitters
    [license_initiated_v1_to_pg,
     offering_terms_accepted_v1_to_pg,
     offering_terms_rejected_v1_to_pg,
     license_bought_v1_to_pg,
     license_abandoned_v1_to_pg,
     license_granted_v1_to_pg,
     license_expired_v1_to_pg,
     license_renewed_v1_to_pg,
     license_revoked_v1_to_pg,
     license_archived_v1_to_pg,
     %% Author offering emitters
     offering_initiated_v1_to_pg,
     offering_announced_v1_to_pg,
     offering_published_v1_to_pg,
     offering_amended_v1_to_pg,
     offering_retracted_v1_to_pg,
     offering_archived_v1_to_pg,
     offering_drafted_v1_to_pg,
     %% Launcher emitters
     entry_registered_v1_to_pg,
     entry_unregistered_v1_to_pg,
     launcher_reorganized_v1_to_pg,
     %% Plugin emitters
     plugin_installed_v1_to_pg, plugin_removed_v1_to_pg,
     plugin_upgraded_v1_to_pg,
     plugin_execution_started_v1_to_pg, plugin_execution_stopped_v1_to_pg,
     container_confirmed_up_v1_to_pg, container_confirmed_down_v1_to_pg,
     oci_pull_started_v1_to_pg, oci_pull_completed_v1_to_pg,
     oci_pull_cancelled_v1_to_pg].

mesh_emitter_modules() ->
    [offering_published_v1_to_mesh].

%% ETS-backed projections (evoq_projection)
ets_projection_modules() ->
    [license_lifecycle_to_licenses,
     offering_lifecycle_to_offerings,
     plugin_lifecycle_to_plugins,
     launcher_lifecycle_to_launcher].

policy_modules() ->
    [on_plugin_installed_register_entry,
     on_plugin_removed_unregister_entry,
     on_plugin_removed_deprovision_container,
     on_plugin_execution_stopped_stop_container,
     on_plugin_upgraded_update_container,
     on_offering_terms_accepted_grant_license,
     on_license_bought_grant_license,
     on_license_granted_install_plugin,
     on_offering_terms_accepted_initiate_procurement,
     on_procurement_initiated_initiate_sale].
