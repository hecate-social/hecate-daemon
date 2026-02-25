%%% @doc Tests for the plugin_aggregate (node context).
%%%
%%% Tests the full lifecycle:
%%%   Install -> Upgrade -> Remove
%%%
%%% Also tests business rules (invalid transitions, re-install after remove).
-module(plugin_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include("plugin_status.hrl").
-include("plugin_state.hrl").

-define(PLUGIN_ID, <<"hecate-social/trader">>).
-define(PLUGIN_NAME, <<"Trader">>).
-define(OCI_IMAGE, <<"ghcr.io/hecate-social/hecate-traderd:0.1.0">>).
-define(OCI_IMAGE_V2, <<"ghcr.io/hecate-social/hecate-traderd:0.2.0">>).
-define(VERSION, <<"0.1.0">>).
-define(VERSION_V2, <<"0.2.0">>).
-define(LICENSE_ID, <<"license-123">>).

%% -- Test Helpers --

fresh_state() ->
    plugin_aggregate:initial_state().

make_install_payload() ->
    #{
        <<"command_type">>      => <<"install_plugin">>,
        <<"plugin_id">>         => ?PLUGIN_ID,
        <<"name">>              => ?PLUGIN_NAME,
        <<"oci_image">>         => ?OCI_IMAGE,
        <<"installed_version">> => ?VERSION,
        <<"license_id">>        => ?LICENSE_ID
    }.

make_upgrade_payload() ->
    #{
        <<"command_type">>      => <<"upgrade_plugin">>,
        <<"plugin_id">>         => ?PLUGIN_ID,
        <<"oci_image">>         => ?OCI_IMAGE_V2,
        <<"installed_version">> => ?VERSION_V2
    }.

make_remove_payload() ->
    #{
        <<"command_type">> => <<"remove_plugin">>,
        <<"plugin_id">>    => ?PLUGIN_ID
    }.

%% Execute a command and apply the resulting events to the state
execute_and_apply(State, Payload) ->
    case plugin_aggregate:execute(State, Payload) of
        {ok, EventMaps} ->
            NewState = lists:foldl(
                fun(E, S) -> plugin_aggregate:apply(S, E) end,
                State,
                EventMaps
            ),
            {ok, NewState, EventMaps};
        {error, _} = Err ->
            Err
    end.

%% -- Initial State Tests --

initial_state_test() ->
    S = fresh_state(),
    ?assertEqual(0, S#plugin_state.status),
    ?assertEqual(undefined, S#plugin_state.plugin_id).

%% -- Install Tests --

install_from_fresh_test() ->
    {ok, S, _Events} = execute_and_apply(fresh_state(), make_install_payload()),
    ?assertNotEqual(0, S#plugin_state.status band ?PLG_INSTALLED),
    ?assertEqual(?PLUGIN_ID, S#plugin_state.plugin_id),
    ?assertEqual(?PLUGIN_NAME, S#plugin_state.name),
    ?assertEqual(?OCI_IMAGE, S#plugin_state.oci_image),
    ?assertEqual(?VERSION, S#plugin_state.installed_version),
    ?assertEqual(?LICENSE_ID, S#plugin_state.license_id),
    ?assertNotEqual(undefined, S#plugin_state.installed_at).

install_event_has_correct_type_test() ->
    {ok, _S, [Event]} = execute_and_apply(fresh_state(), make_install_payload()),
    ?assertEqual(<<"plugin_installed_v1">>,
                 maps:get(<<"event_type">>, Event)).

%% -- Upgrade Tests --

upgrade_after_install_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_install_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_upgrade_payload()),
    ?assertEqual(?OCI_IMAGE_V2, S2#plugin_state.oci_image),
    ?assertEqual(?VERSION_V2, S2#plugin_state.installed_version),
    ?assertNotEqual(undefined, S2#plugin_state.upgraded_at).

upgrade_event_has_correct_type_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_install_payload()),
    {ok, _S2, [Event]} = execute_and_apply(S1, make_upgrade_payload()),
    ?assertEqual(<<"plugin_upgraded_v1">>,
                 maps:get(<<"event_type">>, Event)).

%% -- Remove Tests --

remove_after_install_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_install_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_remove_payload()),
    ?assertNotEqual(0, S2#plugin_state.status band ?PLG_REMOVED),
    ?assertNotEqual(undefined, S2#plugin_state.removed_at).

remove_event_has_correct_type_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_install_payload()),
    {ok, _S2, [Event]} = execute_and_apply(S1, make_remove_payload()),
    ?assertEqual(<<"plugin_removed_v1">>,
                 maps:get(<<"event_type">>, Event)).

%% -- Business Rule Tests (invalid transitions) --

cannot_upgrade_fresh_test() ->
    Result = plugin_aggregate:execute(fresh_state(), make_upgrade_payload()),
    ?assertEqual({error, plugin_not_installed}, Result).

cannot_remove_fresh_test() ->
    Result = plugin_aggregate:execute(fresh_state(), make_remove_payload()),
    ?assertEqual({error, plugin_not_installed}, Result).

cannot_install_twice_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_install_payload()),
    Result = plugin_aggregate:execute(S1, make_install_payload()),
    ?assertEqual({error, plugin_already_installed}, Result).

cannot_upgrade_removed_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_install_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_remove_payload()),
    Result = plugin_aggregate:execute(S2, make_upgrade_payload()),
    ?assertEqual({error, plugin_removed}, Result).

cannot_remove_removed_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_install_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_remove_payload()),
    Result = plugin_aggregate:execute(S2, make_remove_payload()),
    ?assertEqual({error, plugin_removed}, Result).

%% -- Re-install after Remove --

reinstall_after_remove_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_install_payload()),
    {ok, S2, _} = execute_and_apply(S1, make_remove_payload()),
    {ok, S3, _} = execute_and_apply(S2, make_install_payload()),
    ?assertNotEqual(0, S3#plugin_state.status band ?PLG_INSTALLED),
    ?assertEqual(?PLUGIN_ID, S3#plugin_state.plugin_id).

%% -- Bit Flag Tests --

flag_map_test() ->
    Map = plugin_aggregate:flag_map(),
    ?assertEqual(<<"Installed">>, maps:get(1, Map)),
    ?assertEqual(<<"Removed">>, maps:get(2, Map)).

full_lifecycle_flags_test() ->
    {ok, S1, _} = execute_and_apply(fresh_state(), make_install_payload()),
    ?assertEqual(?PLG_INSTALLED, S1#plugin_state.status),

    {ok, S2, _} = execute_and_apply(S1, make_remove_payload()),
    ?assertEqual(?PLG_INSTALLED bor ?PLG_REMOVED, S2#plugin_state.status).
