%%% @doc Tests for on_plugin_installed_provision_container internals.
%%%
%%% Verifies row_to_tuple handles esqlite3 list rows, extract_daemon_name
%%% parses OCI image references, and container_filename generates correct names.
%%% @end
-module(provision_container_tests).

-include_lib("eunit/include/eunit.hrl").

%% -- row_to_tuple --

list_row_to_tuple_test() ->
    Result = on_plugin_installed_provision_container:row_to_tuple(
        [<<"hecate-apps/snake-duel">>, <<"ghcr.io/hecate-apps/hecate-app-snake-dueld:0.1.1">>]),
    ?assertEqual({<<"hecate-apps/snake-duel">>,
                  <<"ghcr.io/hecate-apps/hecate-app-snake-dueld:0.1.1">>}, Result).

tuple_row_to_tuple_test() ->
    Result = on_plugin_installed_provision_container:row_to_tuple(
        {<<"hecate-apps/trader">>, <<"ghcr.io/hecate-apps/hecate-traderd:latest">>}),
    ?assertEqual({<<"hecate-apps/trader">>,
                  <<"ghcr.io/hecate-apps/hecate-traderd:latest">>}, Result).

%% -- extract_daemon_name --

extract_daemon_name_with_tag_test() ->
    ?assertEqual(<<"hecate-app-snake-dueld">>,
        on_plugin_installed_provision_container:extract_daemon_name(
            <<"ghcr.io/hecate-apps/hecate-app-snake-dueld:0.1.1">>)).

extract_daemon_name_latest_test() ->
    ?assertEqual(<<"hecate-traderd">>,
        on_plugin_installed_provision_container:extract_daemon_name(
            <<"ghcr.io/hecate-apps/hecate-traderd:latest">>)).

extract_daemon_name_no_tag_test() ->
    ?assertEqual(<<"hecate-app-snake-dueld">>,
        on_plugin_installed_provision_container:extract_daemon_name(
            <<"ghcr.io/hecate-apps/hecate-app-snake-dueld">>)).

extract_daemon_name_bare_test() ->
    ?assertEqual(<<"hecate-ircd">>,
        on_plugin_installed_provision_container:extract_daemon_name(
            <<"hecate-ircd">>)).

%% -- container_filename --

container_filename_test() ->
    ?assertEqual(<<"hecate-app-snake-dueld.container">>,
        on_plugin_installed_provision_container:container_filename(
            <<"hecate-app-snake-dueld">>)).

container_filename_trader_test() ->
    ?assertEqual(<<"hecate-traderd.container">>,
        on_plugin_installed_provision_container:container_filename(
            <<"hecate-traderd">>)).

%% -- render_container --

render_container_has_restart_always_test() ->
    Content = on_plugin_installed_provision_container:render_container(
        <<"hecate-app-snake-dueld">>, <<"ghcr.io/hecate-apps/hecate-app-snake-dueld:0.1.1">>),
    ?assertNotEqual(nomatch, binary:match(Content, <<"Restart=always">>)),
    ?assertEqual(nomatch, binary:match(Content, <<"Restart=on-failure">>)).

render_container_has_image_test() ->
    Content = on_plugin_installed_provision_container:render_container(
        <<"hecate-traderd">>, <<"ghcr.io/hecate-apps/hecate-traderd:latest">>),
    ?assertNotEqual(nomatch, binary:match(Content, <<"Image=ghcr.io/hecate-apps/hecate-traderd:latest">>)).

render_container_has_auto_update_test() ->
    Content = on_plugin_installed_provision_container:render_container(
        <<"hecate-ircd">>, <<"ghcr.io/hecate-apps/hecate-ircd:latest">>),
    ?assertNotEqual(nomatch, binary:match(Content, <<"AutoUpdate=registry">>)).

render_container_has_container_name_test() ->
    Content = on_plugin_installed_provision_container:render_container(
        <<"hecate-app-snake-dueld">>, <<"ghcr.io/hecate-apps/hecate-app-snake-dueld:0.1.1">>),
    ?assertNotEqual(nomatch, binary:match(Content, <<"ContainerName=hecate-app-snake-dueld">>)).
