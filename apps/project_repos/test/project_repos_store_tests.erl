%%% @doc EUnit tests for project_repos_store + projection.
-module(project_repos_store_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test fixtures
%% ===================================================================

store_lifecycle_test_() ->
    {setup,
     fun setup/0,
     fun teardown/1,
     fun(_) ->
         [
             list_empty(),
             put_and_get(),
             list_by_owner(),
             search_by_tag()
         ]
     end}.

setup() ->
    case ets:info(repos) of
        undefined -> ok;
        _         -> ets:delete(repos)
    end,
    ets:new(repos, [named_table, public, set, {read_concurrency, true}]),
    ok.

teardown(_) ->
    case ets:info(repos) of
        undefined -> ok;
        _         -> ets:delete(repos)
    end.

%% ===================================================================
%% Cases
%% ===================================================================

list_empty() ->
    fun() ->
        ?assertEqual({ok, []}, project_repos_store:list())
    end.

put_and_get() ->
    fun() ->
        Entry = sample_entry(<<"r1">>, <<"did:alice">>, [<<"gitops">>]),
        ets:insert(repos, {<<"r1">>, Entry}),
        ?assertEqual({ok, Entry}, project_repos_store:get(<<"r1">>)),
        ?assertEqual({error, not_found}, project_repos_store:get(<<"nope">>))
    end.

list_by_owner() ->
    fun() ->
        ets:insert(repos, {<<"r1">>, sample_entry(<<"r1">>, <<"did:alice">>, [])}),
        ets:insert(repos, {<<"r2">>, sample_entry(<<"r2">>, <<"did:bob">>,   [])}),
        ets:insert(repos, {<<"r3">>, sample_entry(<<"r3">>, <<"did:alice">>, [])}),
        {ok, AliceRepos} = project_repos_store:list_by_owner(<<"did:alice">>),
        ?assertEqual(2, length(AliceRepos))
    end.

search_by_tag() ->
    fun() ->
        ets:insert(repos, {<<"r1">>, sample_entry(<<"r1">>, <<"did:x">>, [<<"martha-persona">>])}),
        ets:insert(repos, {<<"r2">>, sample_entry(<<"r2">>, <<"did:x">>, [<<"gitops">>])}),
        ets:insert(repos, {<<"r3">>, sample_entry(<<"r3">>, <<"did:x">>, [<<"martha-persona">>, <<"tuned">>])}),
        {ok, Personas} = project_repos_store:search_by_tag(<<"martha-persona">>),
        ?assertEqual(2, length(Personas))
    end.

%% ===================================================================
%% Helpers
%% ===================================================================

sample_entry(RepoId, OwnerDid, Tags) ->
    #{
        repo_id        => RepoId,
        realm          => <<"io.macula">>,
        name           => RepoId,
        owner_did      => OwnerDid,
        description    => <<>>,
        default_branch => <<"main">>,
        visibility     => <<"private">>,
        tags           => Tags,
        status         => <<"active">>,
        initiated_at   => 100,
        revised_at     => undefined,
        archived_at    => undefined
    }.
