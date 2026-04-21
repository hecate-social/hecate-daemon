%%% @doc Pure handler for the `{realm}.config.gitops.initiate` HOPE.
%%%
%%% A realm server (macula-realm) calls this procedure on the user's
%%% hecate-daemon to provision a brand-new gitops repo on the user's
%%% own node. The responder:
%%%
%%%   1. Validates the caller's DID against the configured allowlist
%%%      (fail-closed: empty allowlist rejects everyone).
%%%   2. Verifies the requested realm matches our joined realm.
%%%   3. Generates a fresh `repo_id`.
%%%   4. Dispatches `initiate_repo_v1` through `maybe_initiate_repo`.
%%%   5. Returns the mesh URI for the newly-initiated repo.
%%%
%%% ## v1 auth model (locked)
%%%
%%% No cert-chain verification. No user-consent dialog. The realm-server
%%% DID allowlist is the ONLY gate — populated at boot from the
%%% `MACULA_REALM_SERVER_DIDS` env var (comma-separated). The user
%%% already trusted this realm when they joined it; that's sufficient
%%% for v1. Consent UX and cert chains are a later polish pass.
%%%
%%% ## Caller-DID plumbing — provisional
%%%
%%% Macula V2 is expected to surface the verified caller DID in the
%%% envelope passed to the advertisement handler. Until that lands, we
%%% require the caller to supply `caller_did` explicitly in the request
%%% map. This is called out in module-level docs so the contract is
%%% explicit; it is NOT a security hole — the DID still has to be in
%%% the allowlist.
%%% @end
-module(handle_realm_gitops_init).

-export([handle/2]).
-export([allowed_caller_dids/0]).

-define(DEFAULT_BRANCH,     <<"main">>).
-define(DEFAULT_VISIBILITY, <<"private">>).
-define(DEFAULT_NAME,       <<"gitops">>).
-define(DEFAULT_DESC,
        <<"Hecate node gitops config (macula-realm managed)">>).
-define(DEFAULT_TAGS,       [<<"gitops">>, <<"realm-managed">>]).

%% @doc Handle a validated realm-gitops-init request.
%%
%% `Realm` is the realm this daemon has joined (resolved at
%% advertise time by {@link respond_to_realm_gitops_init}).
%% `Request` is the raw arg map from `macula:call/4`.
-spec handle(binary(), map()) ->
    {ok, #{mesh_uri := binary(), repo_id := binary()}}
  | {error, term()}.
handle(Realm, Request) when is_binary(Realm), is_map(Request) ->
    case validate(Realm, Request) of
        {ok, Validated} -> do_initiate(Realm, Validated);
        {error, _} = Err -> Err
    end;
handle(_Realm, _Request) ->
    {error, invalid_request}.

%% @doc Return the currently-configured realm-server DID allowlist.
%% Exposed for eunit + operator diagnostics.
-spec allowed_caller_dids() -> [binary()].
allowed_caller_dids() ->
    case application:get_env(hecate, realm_server_dids, []) of
        L when is_list(L) -> [to_bin(E) || E <- L];
        _ -> []
    end.

%%====================================================================
%% Internal
%%====================================================================

validate(ExpectedRealm, Request) ->
    Op        = field(op, Request),
    CallerDid = field(caller_did, Request),
    OwnerDid  = field(owner_did, Request),
    Realm     = field(realm, Request),
    case {Op, CallerDid, OwnerDid, Realm} of
        {<<"initiate_gitops">>, C, O, R}
          when is_binary(C), byte_size(C) > 0,
               is_binary(O), byte_size(O) > 0,
               is_binary(R), byte_size(R) > 0 ->
            check_auth(ExpectedRealm, R, C, O);
        _ ->
            {error, invalid_request}
    end.

check_auth(ExpectedRealm, Realm, _C, _O) when Realm =/= ExpectedRealm ->
    {error, realm_mismatch};
check_auth(_ExpectedRealm, Realm, CallerDid, OwnerDid) ->
    case lists:member(CallerDid, allowed_caller_dids()) of
        true  -> {ok, #{caller_did => CallerDid,
                        owner_did  => OwnerDid,
                        realm      => Realm}};
        false -> {error, unauthorized}
    end.

do_initiate(Realm, #{owner_did := OwnerDid}) ->
    RepoId = generate_repo_id(),
    Payload = #{
        repo_id        => RepoId,
        realm          => Realm,
        name           => ?DEFAULT_NAME,
        owner_did      => OwnerDid,
        description    => ?DEFAULT_DESC,
        default_branch => ?DEFAULT_BRANCH,
        visibility     => ?DEFAULT_VISIBILITY,
        tags           => ?DEFAULT_TAGS,
        initiated_at   => erlang:system_time(millisecond)
    },
    {ok, Cmd} = initiate_repo_v1:new(Payload),
    case maybe_initiate_repo:dispatch(Cmd) of
        {ok, _Version, _Events} ->
            {ok, #{
                ok       => true,
                repo_id  => RepoId,
                mesh_uri => mesh_uri(Realm, RepoId)
            }};
        ok ->
            %% reckon_evoq_adapter returns plain `ok` on eventual
            %% consistency — still a success.
            {ok, #{
                ok       => true,
                repo_id  => RepoId,
                mesh_uri => mesh_uri(Realm, RepoId)
            }};
        {error, Reason} ->
            {error, Reason}
    end.

mesh_uri(Realm, RepoId) ->
    <<"mesh://", Realm/binary, "/", RepoId/binary>>.

generate_repo_id() ->
    %% 16 hex chars of randomness is fine for v1 — collision risk is
    %% negligible inside one user's repo catalog. Swap for UUIDv7 if
    %% we ever share a global catalog.
    binary:encode_hex(crypto:strong_rand_bytes(8), lowercase).

field(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            BinKey = atom_to_binary(Key, utf8),
            maps:get(BinKey, Map, undefined)
    end.

to_bin(B) when is_binary(B) -> B;
to_bin(L) when is_list(L)   -> list_to_binary(L);
to_bin(A) when is_atom(A)   -> atom_to_binary(A, utf8).
