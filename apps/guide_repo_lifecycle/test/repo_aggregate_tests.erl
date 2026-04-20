%%% @doc EUnit tests for repo_aggregate lifecycle.
-module(repo_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include("repo_state.hrl").
-include("repo_status.hrl").

%% ===================================================================
%% Initiate
%% ===================================================================

initiate_repo_test() ->
    RepoId = <<"01HZY00000000000000000ABCD">>,
    Payload = base_payload(RepoId),
    {ok, State0} = repo_aggregate:init(RepoId),
    {ok, [Event]} = repo_aggregate:execute(State0,
        Payload#{command_type => initiate_repo}),
    ?assertEqual(<<"repo_initiated_v1">>, maps:get(event_type, Event)),
    ?assertEqual(RepoId, maps:get(repo_id, Event)).

initiate_twice_fails_test() ->
    RepoId = <<"01HZY00000000000000000TWICE">>,
    Payload = base_payload(RepoId),
    {ok, State0} = repo_aggregate:init(RepoId),
    {ok, [Event]} = repo_aggregate:execute(State0,
        Payload#{command_type => initiate_repo}),
    State1 = repo_state:apply_event(State0, Event),
    ?assertEqual({error, already_initiated},
                 repo_aggregate:execute(State1,
                     Payload#{command_type => initiate_repo})).

%% ===================================================================
%% Rename
%% ===================================================================

rename_repo_test() ->
    RepoId = <<"01HZY00000000000000000RENAM">>,
    State1 = initiated_state(RepoId),
    {ok, [Event]} = repo_aggregate:execute(State1, #{
        command_type => rename_repo,
        repo_id      => RepoId,
        new_name     => <<"new-name">>,
        renamed_at   => 1000
    }),
    ?assertEqual(<<"repo_renamed_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"new-name">>, maps:get(new_name, Event)),
    State2 = repo_state:apply_event(State1, Event),
    ?assertEqual(<<"new-name">>, State2#repo_state.name),
    ?assert(evoq_bit_flags:has(State2#repo_state.status, ?REPO_RENAMED)).

rename_not_initiated_test() ->
    {ok, State0} = repo_aggregate:init(<<"blank">>),
    ?assertEqual({error, not_initiated},
                 repo_aggregate:execute(State0, #{
                     command_type => rename_repo,
                     repo_id      => <<"blank">>,
                     new_name     => <<"x">>
                 })).

%% ===================================================================
%% Set description
%% ===================================================================

set_description_test() ->
    RepoId = <<"01HZY00000000000000000DESC">>,
    State1 = initiated_state(RepoId),
    {ok, [Event]} = repo_aggregate:execute(State1, #{
        command_type => set_repo_description,
        repo_id      => RepoId,
        description  => <<"A brand new description">>,
        set_at       => 2000
    }),
    ?assertEqual(<<"repo_description_set_v1">>, maps:get(event_type, Event)),
    State2 = repo_state:apply_event(State1, Event),
    ?assertEqual(<<"A brand new description">>, State2#repo_state.description).

%% ===================================================================
%% Archive
%% ===================================================================

archive_repo_test() ->
    RepoId = <<"01HZY00000000000000000ARCHV">>,
    State1 = initiated_state(RepoId),
    {ok, [Event]} = repo_aggregate:execute(State1, #{
        command_type => archive_repo,
        repo_id      => RepoId,
        reason       => <<"obsolete">>,
        archived_at  => 3000
    }),
    ?assertEqual(<<"repo_archived_v1">>, maps:get(event_type, Event)),
    State2 = repo_state:apply_event(State1, Event),
    ?assert(evoq_bit_flags:has(State2#repo_state.status, ?REPO_ARCHIVED)),
    ?assertEqual({error, archived},
                 repo_aggregate:execute(State2, #{
                     command_type => rename_repo,
                     repo_id      => RepoId,
                     new_name     => <<"too-late">>
                 })),
    ?assertEqual({error, already_archived},
                 repo_aggregate:execute(State2, #{
                     command_type => archive_repo,
                     repo_id      => RepoId
                 })).

%% ===================================================================
%% Validation
%% ===================================================================

invalid_visibility_rejected_test() ->
    RepoId = <<"01HZY00000000000000000VIS">>,
    Payload = base_payload(RepoId),
    {ok, State0} = repo_aggregate:init(RepoId),
    ?assertEqual({error, invalid_visibility},
                 repo_aggregate:execute(State0,
                     Payload#{command_type => initiate_repo,
                              visibility   => <<"bogus">>})).

%% ===================================================================
%% Helpers
%% ===================================================================

base_payload(RepoId) ->
    #{
        repo_id        => RepoId,
        realm          => <<"io.macula">>,
        name           => <<"test-repo">>,
        owner_did      => <<"did:macula:test">>,
        description    => <<"unit test">>,
        default_branch => <<"main">>,
        visibility     => <<"private">>,
        tags           => [<<"test">>],
        initiated_at   => 123
    }.

initiated_state(RepoId) ->
    {ok, S0} = repo_aggregate:init(RepoId),
    Base = base_payload(RepoId),
    Cmd = Base#{command_type => initiate_repo},
    {ok, [Event]} = repo_aggregate:execute(S0, Cmd),
    repo_state:apply_event(S0, Event).
