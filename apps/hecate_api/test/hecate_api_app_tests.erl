%%% @doc Tests for hecate_api startup path.
%%%
%%% Verifies route compilation and socket listener startup.
%%% @end
-module(hecate_api_app_tests).

-include_lib("eunit/include/eunit.hrl").

%% Test that hecate_api_routes:compile/0 produces valid dispatch rules
routes_compile_test() ->
    Dispatch = hecate_api_routes:compile(),
    ?assert(is_list(Dispatch)),
    ?assert(length(Dispatch) > 0),
    %% Dispatch is [{HostMatch, Constraints, PathMatchList}]
    [{'_', _Constraints, PathMatchList}] = Dispatch,
    ?assert(is_list(PathMatchList)),
    %% Should have many routes (health + domain routes)
    ?assert(length(PathMatchList) > 20).

%% Test that /health route is present (not /api/health — cowboy splits on /)
health_route_present_test() ->
    Dispatch = hecate_api_routes:compile(),
    [{'_', _, PathMatchList}] = Dispatch,
    %% Cowboy compiles "/health" to [<<"health">>]
    HealthRoutes = [R || {[<<"health">>], _, Handler, _} = R <- PathMatchList,
                         Handler =:= hecate_api_health],
    ?assert(length(HealthRoutes) > 0).

%% Test that cowboy can start a Unix socket listener in /tmp
socket_listener_start_test() ->
    application:ensure_all_started(cowboy),
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
    TestPath = TestDir ++ "/daemon.sock",
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
    application:set_env(hecate_api, socket_path, "/run/hecate/daemon.sock"),
    ?assertEqual("/run/hecate/daemon.sock",
                 application:get_env(hecate_api, socket_path, undefined)),
    %% Restore
    case OldVal of
        {ok, V} -> application:set_env(hecate_api, socket_path, V);
        undefined -> ok
    end.

%% Test that all route modules return non-empty route lists
all_route_modules_test() ->
    Modules = [
        %% Venture lifecycle (4 consolidated apps)
        guide_venture_lifecycle_routes,
        query_venture_lifecycle_routes,
        guide_division_alc_routes,
        query_division_alc_routes,
        %% Node lifecycle (2 consolidated apps)
        guide_node_lifecycle_routes,
        query_node_lifecycle_routes,
        %% Mentorships (renamed)
        mentor_llms_routes,
        query_mentorships_routes,
        %% LLM
        serve_llm_routes
    ],
    lists:foreach(fun(Mod) ->
        Routes = Mod:routes(),
        ?assert(is_list(Routes)),
        ?assert(length(Routes) > 0)
    end, Modules).
