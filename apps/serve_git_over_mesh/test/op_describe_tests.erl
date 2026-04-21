%%% @doc EUnit tests for `op_describe:run/1`.
%%%
%%% Populates the `repos` ETS read model directly (bypassing the
%%% projection) and asserts that `op_describe:run/1` returns a
%%% well-formed metadata map.
-module(op_describe_tests).

-include_lib("eunit/include/eunit.hrl").

describe_test_() ->
    {setup,
     fun setup/0,
     fun teardown/1,
     fun(_) ->
         [
             found_returns_metadata(),
             missing_returns_error()
         ]
     end}.

setup() ->
    %% Ensure a predictable repo_root so size_bytes is deterministic.
    TmpRoot = filename:join("/tmp",
        "op-describe-" ++ os:getpid() ++ "-"
            ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(TmpRoot),
    application:set_env(serve_git_over_mesh, repo_root, TmpRoot),
    case ets:info(repos) of
        undefined -> ok;
        _         -> ets:delete(repos)
    end,
    ets:new(repos, [named_table, public, set, {read_concurrency, true}]),
    TmpRoot.

teardown(TmpRoot) ->
    case ets:info(repos) of
        undefined -> ok;
        _         -> ets:delete(repos)
    end,
    application:unset_env(serve_git_over_mesh, repo_root),
    os:cmd("rm -rf " ++ TmpRoot),
    ok.

%% ===================================================================
%% Cases
%% ===================================================================

found_returns_metadata() ->
    fun() ->
        ets:insert(repos, {<<"r1">>, #{
            repo_id        => <<"r1">>,
            realm          => <<"io.macula">>,
            name           => <<"my-config">>,
            owner_did      => <<"did:alice">>,
            description    => <<"Just config.">>,
            default_branch => <<"trunk">>,
            visibility     => <<"private">>,
            tags           => [<<"gitops">>],
            status         => <<"active">>,
            initiated_at   => 100
        }}),
        Result = op_describe:run(<<"r1">>),
        ?assertEqual(true,           maps:get(ok, Result)),
        ?assertEqual(<<"my-config">>, maps:get(name, Result)),
        ?assertEqual(<<"trunk">>,    maps:get(default_branch, Result)),
        ?assertEqual([<<"gitops">>], maps:get(tags, Result)),
        ?assertEqual(0,              maps:get(size_bytes, Result))
    end.

missing_returns_error() ->
    fun() ->
        Result = op_describe:run(<<"never-existed">>),
        ?assertEqual(false, maps:get(ok, Result)),
        ?assertEqual(<<"repo_not_found">>, maps:get(error, Result))
    end.
