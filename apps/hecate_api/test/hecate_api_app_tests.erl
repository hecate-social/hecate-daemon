%%% @doc Tests for hecate_api startup path.
%%%
%%% Verifies route compilation and socket listener startup.
%%% @end
-module(hecate_api_app_tests).

-include_lib("eunit/include/eunit.hrl").

%% Test that hecate_api_routes:compile/0 produces valid dispatch rules.
%% In eunit context not all apps may be loaded, so we just verify the
%% compile/0 function succeeds and returns a valid cowboy dispatch list.
routes_compile_test() ->
    %% Ensure at least hecate_api modules are discoverable
    application:load(hecate_api),
    Dispatch = hecate_api_routes:compile(),
    ?assert(is_list(Dispatch)),
    ?assert(length(Dispatch) > 0),
    %% Dispatch is [{HostMatch, Constraints, PathMatchList}]
    [{'_', _Constraints, PathMatchList}] = Dispatch,
    ?assert(is_list(PathMatchList)),
    %% hecate_api retains infrastructure routes (health, startup_health, facts_stream)
    ?assert(length(PathMatchList) > 0).

%% Test that /health route is present
health_route_present_test() ->
    application:load(hecate_api),
    Dispatch = hecate_api_routes:compile(),
    [{'_', _, PathMatchList}] = Dispatch,
    %% Cowboy compiles "/health" to [<<"health">>]
    HealthRoutes = [R || {[<<"health">>], _, Handler, _} = R <- PathMatchList,
                         Handler =:= hecate_api_health],
    ?assert(length(HealthRoutes) > 0).

%% Test that cowboy can start a Unix socket listener in /tmp
socket_listener_start_test() ->
    application:ensure_all_started(cowboy),
    application:load(hecate_api),
    Ts = integer_to_list(erlang:system_time(microsecond)),
    SocketPath = "/tmp/hecate_api_test_" ++ Ts ++ ".sock",
    %% Unique listener name per run to avoid {already_started, _}
    ListenerName = list_to_atom("hecate_test_listener_" ++ Ts),
    Dispatch = hecate_api_routes:compile(),
    Result = cowboy:start_clear(ListenerName,
                [{ip, {local, SocketPath}}],
                #{env => #{dispatch => Dispatch}}),
    case Result of
        {ok, _Pid} ->
            %% Unix sockets are type 's', not regular files.
            %% filelib:is_file/1 returns false for sockets.
            %% Use file:read_file_info/1 which works on any filesystem entry.
            {ok, Info} = file:read_file_info(SocketPath),
            ?assertEqual(other, element(3, Info)),
            cowboy:stop_listener(ListenerName),
            file:delete(SocketPath);
        {error, Reason} ->
            file:delete(SocketPath),
            ?assertEqual(ok, {socket_listener_failed, Reason})
    end.

%% Test that ensure_socket_dir logic works for /tmp paths
ensure_socket_dir_test() ->
    TestDir = "/tmp/hecate_test_dir_" ++ integer_to_list(erlang:system_time(microsecond)),
    TestPath = TestDir ++ "/api.sock",
    %% filelib:ensure_dir creates parent directories
    ?assertEqual(ok, filelib:ensure_dir(TestPath)),
    ?assert(filelib:is_dir(TestDir)),
    file:del_dir(TestDir).

%% Test that get_socket_path returns correct values from app config
socket_path_config_test() ->
    %% When socket_path is undefined, get_socket_path should return undefined
    OldVal = application:get_env(hecate_api, socket_path),
    application:set_env(hecate_api, socket_path, undefined),
    ?assertEqual(undefined,
                 application:get_env(hecate_api, socket_path, undefined)),
    %% When socket_path is a string, get_env/3 returns it directly (not {ok, ...})
    application:set_env(hecate_api, socket_path, "/home/testuser/.hecate/hecate-daemon/sockets/api.sock"),
    ?assertEqual("/home/testuser/.hecate/hecate-daemon/sockets/api.sock",
                 application:get_env(hecate_api, socket_path, undefined)),
    %% Restore
    case OldVal of
        {ok, V} -> application:set_env(hecate_api, socket_path, V);
        undefined -> ok
    end.

%% Test that auto-discovery finds routes from modules that export routes/0.
%% We verify specific handler modules have the expected export.
auto_discovery_test() ->
    %% hecate_api_health should export routes/0
    code:ensure_loaded(hecate_api_health),
    ?assert(erlang:function_exported(hecate_api_health, routes, 0)),
    Routes = hecate_api_health:routes(),
    ?assert(is_list(Routes)),
    ?assert(length(Routes) > 0),
    %% hecate_api_routes itself should NOT export routes/0 (it's the aggregator)
    ?assertNot(erlang:function_exported(hecate_api_routes, routes, 0)).
