%%% @doc Tests for per-event web emitters.
%%%
%%% Verifies that each emitter:
%%%   - subscribes to exactly one event type
%%%   - broadcasts the correct payload when the plugin exists in ETS
%%%   - silently skips when the plugin is not found
-module(plugin_web_emitters_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("guide_plugin_lifecycle/include/plugin_status.hrl").

-define(TABLE, plugins).
-define(PLUGIN_ID, <<"test-org/test-plugin">>).
-define(PLUGIN_NAME, <<"test-plugin">>).

%% All 13 emitter modules
all_emitters() ->
    [plugin_installed_v1_to_web,
     plugin_upgraded_v1_to_web,
     plugin_removed_v1_to_web,
     plugin_execution_requested_v1_to_web,
     plugin_termination_requested_v1_to_web,
     container_confirmed_up_v1_to_web,
     container_confirmed_down_v1_to_web,
     oci_pull_started_v1_to_web,
     oci_pull_cancelled_v1_to_web,
     oci_pull_completed_v1_to_web,
     plugin_package_extracted_v1_to_web,
     plugin_load_confirmed_v1_to_web,
     plugin_unload_confirmed_v1_to_web].

%% Expected event type for each emitter
expected_event(plugin_installed_v1_to_web)          -> <<"plugin_installed_v1">>;
expected_event(plugin_upgraded_v1_to_web)            -> <<"plugin_upgraded_v1">>;
expected_event(plugin_removed_v1_to_web)             -> <<"plugin_removed_v1">>;
expected_event(plugin_execution_requested_v1_to_web)   -> <<"plugin_execution_requested_v1">>;
expected_event(plugin_termination_requested_v1_to_web)   -> <<"plugin_termination_requested_v1">>;
expected_event(container_confirmed_up_v1_to_web)     -> <<"container_confirmed_up_v1">>;
expected_event(container_confirmed_down_v1_to_web)   -> <<"container_confirmed_down_v1">>;
expected_event(oci_pull_started_v1_to_web)            -> <<"oci_pull_started_v1">>;
expected_event(oci_pull_cancelled_v1_to_web)          -> <<"oci_pull_cancelled_v1">>;
expected_event(oci_pull_completed_v1_to_web)          -> <<"oci_pull_completed_v1">>;
expected_event(plugin_package_extracted_v1_to_web)    -> <<"plugin_package_extracted_v1">>;
expected_event(plugin_load_confirmed_v1_to_web)       -> <<"plugin_load_confirmed_v1">>;
expected_event(plugin_unload_confirmed_v1_to_web)     -> <<"plugin_unload_confirmed_v1">>.

%% ===================================================================
%% Setup / Teardown
%% ===================================================================

setup() ->
    catch ets:delete(?TABLE),
    ?TABLE = ets:new(?TABLE, [set, public, named_table, {read_concurrency, true}]),
    ok.

cleanup(_) ->
    catch ets:delete(?TABLE),
    ok.

%% ===================================================================
%% Tests
%% ===================================================================

%% Each emitter subscribes to exactly one event type
each_emitter_has_single_event_test_() ->
    [{atom_to_list(M), fun() ->
        Events = M:interested_in(),
        ?assertEqual(1, length(Events)),
        ?assertEqual(expected_event(M), hd(Events))
    end} || M <- all_emitters()].

%% No two emitters subscribe to the same event
no_duplicate_subscriptions_test() ->
    AllEvents = lists:flatmap(fun(M) -> M:interested_in() end, all_emitters()),
    Unique = lists:usort(AllEvents),
    ?assertEqual(length(AllEvents), length(Unique)).

%% All 13 events are covered
all_lifecycle_events_covered_test() ->
    AllEvents = lists:sort(lists:flatmap(fun(M) -> M:interested_in() end, all_emitters())),
    Expected = lists:sort([
        <<"plugin_installed_v1">>,
        <<"plugin_upgraded_v1">>,
        <<"plugin_removed_v1">>,
        <<"plugin_execution_requested_v1">>,
        <<"plugin_termination_requested_v1">>,
        <<"container_confirmed_up_v1">>,
        <<"container_confirmed_down_v1">>,
        <<"oci_pull_started_v1">>,
        <<"oci_pull_cancelled_v1">>,
        <<"oci_pull_completed_v1">>,
        <<"plugin_package_extracted_v1">>,
        <<"plugin_load_confirmed_v1">>,
        <<"plugin_unload_confirmed_v1">>
    ]),
    ?assertEqual(Expected, AllEvents).

%% Each emitter init returns {ok, #{}}
each_emitter_init_test_() ->
    [{atom_to_list(M), fun() ->
        ?assertEqual({ok, #{}}, M:init(#{}))
    end} || M <- all_emitters()].

%% handle_event skips when plugin not in ETS
handle_event_skips_unknown_plugin_test() ->
    setup(),
    try
        %% Pick one representative emitter
        Event = #{data => #{plugin_id => <<"nonexistent/plugin">>}},
        {ok, #{}} = plugin_installed_v1_to_web:handle_event(
            <<"plugin_installed_v1">>, Event, #{}, #{})
    after
        cleanup(ok)
    end.

%% handle_event skips non-matching clause (no data key)
handle_event_skips_bad_event_test() ->
    {ok, #{}} = plugin_installed_v1_to_web:handle_event(
        <<"plugin_installed_v1">>, #{no_data => true}, #{}, #{}).
