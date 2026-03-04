%%% @doc Tests for on_plugin_installed_provision_container internals.
%%%
%%% Verifies row_to_tuple handles esqlite3 list rows, extract_plugin_name
%%% parses org/name format, and container_filename generates correct names.
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

%% -- extract_plugin_name --

extract_name_with_org_test() ->
    ?assertEqual(<<"snake-duel">>,
        on_plugin_installed_provision_container:extract_plugin_name(
            <<"hecate-apps/snake-duel">>)).

extract_name_without_org_test() ->
    ?assertEqual(<<"trader">>,
        on_plugin_installed_provision_container:extract_plugin_name(
            <<"trader">>)).

%% -- container_filename --

container_filename_test() ->
    ?assertEqual(<<"hecate-snake-dueld.container">>,
        on_plugin_installed_provision_container:container_filename(
            <<"snake-duel">>)).

container_filename_trader_test() ->
    ?assertEqual(<<"hecate-traderd.container">>,
        on_plugin_installed_provision_container:container_filename(
            <<"trader">>)).

%% -- render_container --

render_container_has_restart_always_test() ->
    Content = on_plugin_installed_provision_container:render_container(
        <<"snake-duel">>, <<"ghcr.io/hecate-apps/hecate-app-snake-dueld:0.1.1">>),
    ?assertNotEqual(nomatch, binary:match(Content, <<"Restart=always">>)),
    ?assertEqual(nomatch, binary:match(Content, <<"Restart=on-failure">>)).

render_container_has_image_test() ->
    Content = on_plugin_installed_provision_container:render_container(
        <<"trader">>, <<"ghcr.io/hecate-apps/hecate-traderd:latest">>),
    ?assertNotEqual(nomatch, binary:match(Content, <<"Image=ghcr.io/hecate-apps/hecate-traderd:latest">>)).

render_container_has_auto_update_test() ->
    Content = on_plugin_installed_provision_container:render_container(
        <<"irc">>, <<"ghcr.io/hecate-apps/hecate-ircd:latest">>),
    ?assertNotEqual(nomatch, binary:match(Content, <<"AutoUpdate=registry">>)).
