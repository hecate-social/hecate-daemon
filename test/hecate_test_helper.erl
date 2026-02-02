%%%-------------------------------------------------------------------
%%% @doc Test helper for Hecate tests.
%%%
%%% Provides common setup/teardown for isolated test environments.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_test_helper).

-export([
    setup/0,
    cleanup/0,
    setup_store/0,
    cleanup_store/0,
    temp_dir/0
]).

%% @doc Full application setup for integration tests
-spec setup() -> ok.
setup() ->
    setup_store(),
    ok.

%% @doc Cleanup after tests
-spec cleanup() -> ok.
cleanup() ->
    cleanup_store(),
    ok.

%% @doc Setup isolated store with temp directory
-spec setup_store() -> ok.
setup_store() ->
    TempDir = temp_dir(),
    ok = filelib:ensure_dir(filename:join(TempDir, "dummy")),
    application:set_env(hecate, data_dir, TempDir),
    ok.

%% @doc Cleanup temp store
-spec cleanup_store() -> ok.
cleanup_store() ->
    TempDir = temp_dir(),
    os:cmd("rm -rf " ++ TempDir),
    ok.

%% @doc Generate unique temp directory for test isolation
-spec temp_dir() -> string().
temp_dir() ->
    Unique = integer_to_list(erlang:unique_integer([positive])),
    filename:join(["/tmp", "hecate_test_" ++ Unique]).
