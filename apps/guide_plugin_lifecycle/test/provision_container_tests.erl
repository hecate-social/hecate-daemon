%%% @doc Tests for container provisioning internals.
%%%
%%% Container provisioning helpers live in shared_podman.
%%% @end
-module(provision_container_tests).

-include_lib("eunit/include/eunit.hrl").

%% -- extract_daemon_name --

extract_daemon_name_with_tag_test() ->
    ?assertEqual(<<"hecate-app-snake-dueld">>,
        shared_podman:extract_daemon_name(
            <<"ghcr.io/hecate-apps/hecate-app-snake-dueld:0.1.1">>)).

extract_daemon_name_latest_test() ->
    ?assertEqual(<<"hecate-traderd">>,
        shared_podman:extract_daemon_name(
            <<"ghcr.io/hecate-apps/hecate-traderd:latest">>)).

extract_daemon_name_no_tag_test() ->
    ?assertEqual(<<"hecate-app-snake-dueld">>,
        shared_podman:extract_daemon_name(
            <<"ghcr.io/hecate-apps/hecate-app-snake-dueld">>)).

extract_daemon_name_bare_test() ->
    ?assertEqual(<<"hecate-ircd">>,
        shared_podman:extract_daemon_name(
            <<"hecate-ircd">>)).

%% -- container_filename --

container_filename_test() ->
    ?assertEqual(<<"hecate-app-snake-dueld.container">>,
        shared_podman:container_filename(
            <<"hecate-app-snake-dueld">>)).

container_filename_trader_test() ->
    ?assertEqual(<<"hecate-traderd.container">>,
        shared_podman:container_filename(
            <<"hecate-traderd">>)).

%% -- render_container --

render_container_has_restart_always_test() ->
    Content = shared_podman:render_container(
        <<"hecate-app-snake-dueld">>, <<"ghcr.io/hecate-apps/hecate-app-snake-dueld:0.1.1">>),
    ?assertNotEqual(nomatch, binary:match(Content, <<"Restart=always">>)),
    ?assertEqual(nomatch, binary:match(Content, <<"Restart=on-failure">>)).

render_container_has_image_test() ->
    Content = shared_podman:render_container(
        <<"hecate-traderd">>, <<"ghcr.io/hecate-apps/hecate-traderd:latest">>),
    ?assertNotEqual(nomatch, binary:match(Content, <<"Image=ghcr.io/hecate-apps/hecate-traderd:latest">>)).

render_container_has_auto_update_test() ->
    Content = shared_podman:render_container(
        <<"hecate-ircd">>, <<"ghcr.io/hecate-apps/hecate-ircd:latest">>),
    ?assertNotEqual(nomatch, binary:match(Content, <<"AutoUpdate=registry">>)).

render_container_has_container_name_test() ->
    Content = shared_podman:render_container(
        <<"hecate-app-snake-dueld">>, <<"ghcr.io/hecate-apps/hecate-app-snake-dueld:0.1.1">>),
    ?assertNotEqual(nomatch, binary:match(Content, <<"ContainerName=hecate-app-snake-dueld">>)).
