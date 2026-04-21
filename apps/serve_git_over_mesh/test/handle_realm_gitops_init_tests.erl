%%% @doc EUnit tests for `handle_realm_gitops_init:handle/2`.
%%%
%%% The happy-path test stubs `maybe_initiate_repo:dispatch/1` via
%%% `meck` to avoid spinning up reckon-db. Validation + auth paths
%%% don't need any stubbing.
-module(handle_realm_gitops_init_tests).

-include_lib("eunit/include/eunit.hrl").

-define(REALM,      <<"io.macula">>).
-define(CALLER_DID, <<"did:macula:realm:macula.io">>).
-define(OWNER_DID,  <<"did:macula:agent:io.macula/alice">>).

%%====================================================================
%% Fixtures
%%====================================================================

allowlist_fixture(Test) ->
    {setup,
     fun() ->
         application:set_env(hecate, realm_server_dids, [?CALLER_DID]),
         ok
     end,
     fun(_) ->
         application:unset_env(hecate, realm_server_dids)
     end,
     Test}.

empty_allowlist_fixture(Test) ->
    {setup,
     fun() ->
         application:set_env(hecate, realm_server_dids, []),
         ok
     end,
     fun(_) ->
         application:unset_env(hecate, realm_server_dids)
     end,
     Test}.

%%====================================================================
%% Validation — negative paths (no dispatch needed)
%%====================================================================

missing_fields_returns_invalid_request_test() ->
    ?assertEqual({error, invalid_request},
                 handle_realm_gitops_init:handle(?REALM, #{})),
    ?assertEqual({error, invalid_request},
                 handle_realm_gitops_init:handle(?REALM,
                   #{op => <<"initiate_gitops">>})),
    ?assertEqual({error, invalid_request},
                 handle_realm_gitops_init:handle(?REALM,
                   #{op         => <<"initiate_gitops">>,
                     caller_did => ?CALLER_DID})).

wrong_op_returns_invalid_request_test() ->
    Req = request_map(<<"install_plugin">>, ?CALLER_DID, ?OWNER_DID, ?REALM),
    ?assertEqual({error, invalid_request},
                 handle_realm_gitops_init:handle(?REALM, Req)).

non_map_returns_invalid_request_test() ->
    ?assertEqual({error, invalid_request},
                 handle_realm_gitops_init:handle(?REALM, not_a_map)).

%%====================================================================
%% Auth — unauthorized + realm-mismatch paths
%%====================================================================

unauthorized_when_allowlist_empty_test_() ->
    empty_allowlist_fixture(
      fun() ->
          Req = request_map(<<"initiate_gitops">>, ?CALLER_DID,
                            ?OWNER_DID, ?REALM),
          ?assertEqual({error, unauthorized},
                       handle_realm_gitops_init:handle(?REALM, Req))
      end).

unauthorized_when_caller_not_in_allowlist_test_() ->
    allowlist_fixture(
      fun() ->
          Req = request_map(<<"initiate_gitops">>,
                            <<"did:rogue:other">>, ?OWNER_DID, ?REALM),
          ?assertEqual({error, unauthorized},
                       handle_realm_gitops_init:handle(?REALM, Req))
      end).

realm_mismatch_beats_allowlist_test_() ->
    %% Realm is checked before allowlist — a mismatched realm does NOT
    %% leak the allowlist state.
    allowlist_fixture(
      fun() ->
          Req = request_map(<<"initiate_gitops">>, ?CALLER_DID,
                            ?OWNER_DID, <<"io.other-realm">>),
          ?assertEqual({error, realm_mismatch},
                       handle_realm_gitops_init:handle(?REALM, Req))
      end).

%%====================================================================
%% Happy path — requires meck for the dispatch
%%====================================================================

happy_path_returns_mesh_uri_test_() ->
    allowlist_fixture(
      fun() ->
          meck:new(maybe_initiate_repo, [non_strict, passthrough]),
          meck:expect(maybe_initiate_repo, dispatch,
                      fun(_Cmd) -> {ok, 1, []} end),
          try
              Req = request_map(<<"initiate_gitops">>, ?CALLER_DID,
                                ?OWNER_DID, ?REALM),
              Result = handle_realm_gitops_init:handle(?REALM, Req),
              ?assertMatch({ok, #{mesh_uri := <<"mesh://", _/binary>>,
                                  repo_id  := _,
                                  ok       := true}},
                           Result),
              {ok, #{mesh_uri := Uri, repo_id := RepoId}} = Result,
              Expected = <<"mesh://", ?REALM/binary, "/", RepoId/binary>>,
              ?assertEqual(Expected, Uri)
          after
              meck:unload(maybe_initiate_repo)
          end
      end).

%%====================================================================
%% Internal
%%====================================================================

request_map(Op, CallerDid, OwnerDid, Realm) ->
    #{op         => Op,
      caller_did => CallerDid,
      owner_did  => OwnerDid,
      realm      => Realm}.
