%%%-------------------------------------------------------------------
%%% @doc Hecate identity management.
%%%
%%% Handles MRI (Macula Resource Identifier) and Ed25519 keypair.
%%% Identity is per-node and persisted as an encrypted file at
%%% ~/.hecate/hecate-daemon/identity.enc (AES-256-GCM, cookie-derived key).
%%%
%%% The private key MUST NOT replicate — it stays local to this node.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_identity).
-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([
    get_mri/0,
    get_realm/0,
    get_public_key/0,
    get_encryption_public_key/0,
    encryption_keypair/0,
    agent_id/0,
    sign/1,
    verify/2,
    is_initialized/0,
    initialize/1,
    update_owner/1
]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to public_key (excluded from PLT)
-dialyzer({nowarn_function, [handle_call/3]}).

-define(SERVER, ?MODULE).
-define(IDENTITY_FILE, "identity.enc").

-record(state, {
    mri :: binary() | undefined,
    realm :: binary() | undefined,
    public_key :: binary() | undefined,         % Ed25519 signing pubkey
    private_key :: binary() | undefined,        % Ed25519 signing privkey
    encryption_public_key :: binary() | undefined,   % X25519 encryption pubkey
    encryption_private_key :: binary() | undefined   % X25519 encryption privkey
}).

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec get_mri() -> {ok, binary()} | not_initialized.
get_mri() ->
    gen_server:call(?SERVER, get_mri).

-spec get_realm() -> {ok, binary()} | not_initialized.
get_realm() ->
    gen_server:call(?SERVER, get_realm).

-spec get_public_key() -> {ok, binary()} | not_initialized.
get_public_key() ->
    gen_server:call(?SERVER, get_public_key).

%% @doc X25519 encryption pubkey for DID-scope license wrapping.
-spec get_encryption_public_key() -> {ok, binary()} | not_initialized.
get_encryption_public_key() ->
    gen_server:call(?SERVER, get_encryption_public_key).

%% @doc Full X25519 keypair — use sparingly; the private key should
%% only be consumed by `hecate_did_crypto:unwrap_with_privkey/2`.
-spec encryption_keypair() -> {ok, {binary(), binary()}} | not_initialized.
encryption_keypair() ->
    gen_server:call(?SERVER, encryption_keypair).

-spec agent_id() -> binary().
agent_id() ->
    case get_mri() of
        {ok, MRI} -> MRI;
        not_initialized -> <<"mri:agent:io.macula/hecate">>
    end.

-spec sign(Data :: binary()) -> {ok, binary()} | not_initialized.
sign(Data) ->
    gen_server:call(?SERVER, {sign, Data}).

-spec verify(Data :: binary(), Signature :: binary()) -> boolean().
verify(Data, Signature) ->
    gen_server:call(?SERVER, {verify, Data, Signature}).

-spec is_initialized() -> boolean().
is_initialized() ->
    gen_server:call(?SERVER, is_initialized).

-spec initialize(Opts :: map()) -> ok | {error, term()}.
initialize(Opts) ->
    gen_server:call(?SERVER, {initialize, Opts}).

-spec update_owner(binary()) -> ok | {error, term()}.
update_owner(NewOwner) ->
    gen_server:call(?SERVER, {update_owner, NewOwner}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    State = case load_identity() of
        {ok, Identity} ->
            logger:info("Loaded identity: ~s", [maps:get(mri, Identity)]),
            maybe_upgrade_encryption_keypair(identity_to_state(Identity));
        not_found ->
            auto_initialize()
    end,
    {ok, maybe_fix_anonymous_owner(State)}.

handle_call(get_mri, _From, #state{mri = undefined} = State) ->
    {reply, not_initialized, State};
handle_call(get_mri, _From, #state{mri = MRI} = State) ->
    {reply, {ok, MRI}, State};

handle_call(get_realm, _From, #state{realm = undefined} = State) ->
    {reply, not_initialized, State};
handle_call(get_realm, _From, #state{realm = Realm} = State) ->
    {reply, {ok, Realm}, State};

handle_call(get_public_key, _From, #state{public_key = undefined} = State) ->
    {reply, not_initialized, State};
handle_call(get_public_key, _From, #state{public_key = PubKey} = State) ->
    {reply, {ok, PubKey}, State};

handle_call(get_encryption_public_key, _From,
            #state{encryption_public_key = undefined} = State) ->
    {reply, not_initialized, State};
handle_call(get_encryption_public_key, _From,
            #state{encryption_public_key = Pub} = State) ->
    {reply, {ok, Pub}, State};

handle_call(encryption_keypair, _From,
            #state{encryption_public_key = undefined} = State) ->
    {reply, not_initialized, State};
handle_call(encryption_keypair, _From,
            #state{encryption_public_key = Pub,
                   encryption_private_key = Priv} = State) ->
    {reply, {ok, {Pub, Priv}}, State};

handle_call({sign, _Data}, _From, #state{private_key = undefined} = State) ->
    {reply, not_initialized, State};
handle_call({sign, Data}, _From, #state{private_key = PrivKey} = State) ->
    Signature = public_key:sign(Data, none, {ed_pri, ed25519, undefined, PrivKey}),
    {reply, {ok, Signature}, State};

handle_call({verify, Data, Signature}, _From, #state{public_key = PubKey} = State) ->
    Result = public_key:verify(Data, none, Signature, {ed_pub, ed25519, PubKey}),
    {reply, Result, State};

handle_call(is_initialized, _From, #state{mri = MRI} = State) ->
    {reply, MRI =/= undefined, State};

handle_call({initialize, Opts}, _From, #state{mri = undefined} = _State) ->
    {PubKey, PrivKey} = generate_keypair(),
    {EncPub, EncPriv} = generate_encryption_keypair(),
    Realm = maps:get(realm, Opts, <<"io.macula">>),
    Name = maps:get(name, Opts, generate_name()),
    Owner = maps:get(owner, Opts, <<"anonymous">>),
    MRI = build_mri(Realm, Owner, Name),

    Identity = #{
        mri => MRI, realm => Realm,
        public_key => PubKey, private_key => PrivKey,
        encryption_public_key => EncPub,
        encryption_private_key => EncPriv
    },
    save_identity(Identity),
    logger:info("Created identity: ~s", [MRI]),

    NewState = #state{
        mri = MRI, realm = Realm,
        public_key = PubKey, private_key = PrivKey,
        encryption_public_key = EncPub,
        encryption_private_key = EncPriv
    },
    {reply, ok, NewState};

handle_call({initialize, _Opts}, _From, State) ->
    {reply, {error, already_initialized}, State};

handle_call({update_owner, NewOwner}, _From, #state{mri = MRI} = State) when MRI =/= undefined ->
    case parse_mri_owner(MRI) of
        <<"anonymous">> ->
            NewMRI = replace_mri_owner(MRI, NewOwner),
            Identity = state_to_identity(State#state{mri = NewMRI}),
            save_identity(Identity),
            logger:info("Updated identity owner: ~s -> ~s", [MRI, NewMRI]),
            hecate_web_events:broadcast(identity_changed, #{mri => NewMRI}),
            {reply, ok, State#state{mri = NewMRI}};
        _ ->
            {reply, {error, already_claimed}, State}
    end;
handle_call({update_owner, _}, _From, State) ->
    {reply, {error, not_initialized}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%%===================================================================
%%% Encrypted file persistence
%%%===================================================================

%% @private Load identity from encrypted file.
-spec load_identity() -> {ok, map()} | not_found.
load_identity() ->
    Path = identity_path(),
    case file:read_file(Path) of
        {ok, EncData} ->
            case hecate_crypto:decrypt(EncData) of
                {ok, Serialized} -> {ok, binary_to_term(Serialized)};
                {error, _} ->
                    logger:warning("Failed to decrypt identity file — cookie may have changed"),
                    not_found
            end;
        {error, enoent} ->
            not_found;
        {error, Reason} ->
            logger:warning("Failed to read identity file: ~p", [Reason]),
            not_found
    end.

%% @private Save identity to encrypted file.
-spec save_identity(map()) -> ok.
save_identity(Identity) ->
    Path = identity_path(),
    ok = filelib:ensure_dir(Path),
    Serialized = term_to_binary(Identity),
    {ok, EncData} = hecate_crypto:encrypt(Serialized),
    ok = file:write_file(Path, EncData).

%% @private Path to identity file.
-spec identity_path() -> file:filename().
identity_path() ->
    filename:join(shared_paths:base_dir(), ?IDENTITY_FILE).

%%%===================================================================
%%% Internal functions
%%%===================================================================

auto_initialize() ->
    logger:info("No identity found — generating on first boot"),
    {PubKey, PrivKey} = generate_keypair(),
    {EncPub, EncPriv} = generate_encryption_keypair(),
    Realm = <<"io.macula">>,
    Name = generate_name(),
    Owner = <<"anonymous">>,
    MRI = build_mri(Realm, Owner, Name),
    Identity = #{
        mri => MRI, realm => Realm,
        public_key => PubKey, private_key => PrivKey,
        encryption_public_key => EncPub,
        encryption_private_key => EncPriv
    },
    save_identity(Identity),
    logger:info("Created identity: ~s", [MRI]),
    #state{
        mri = MRI, realm = Realm,
        public_key = PubKey, private_key = PrivKey,
        encryption_public_key = EncPub,
        encryption_private_key = EncPriv
    }.

%% @private Upgrade state to have encryption keypair. Existing identity
%% files (pre-Phase-D) lack these fields; we generate + persist lazily.
maybe_upgrade_encryption_keypair(#state{encryption_public_key = undefined} = State)
  when State#state.mri =/= undefined ->
    {EncPub, EncPriv} = generate_encryption_keypair(),
    UpgradedState = State#state{
        encryption_public_key = EncPub,
        encryption_private_key = EncPriv
    },
    save_identity(state_to_identity(UpgradedState)),
    logger:info("[identity] encryption keypair generated + persisted"),
    UpgradedState;
maybe_upgrade_encryption_keypair(State) ->
    State.

%% @private
identity_to_state(Identity) ->
    #state{
        mri = maps:get(mri, Identity),
        realm = maps:get(realm, Identity),
        public_key = maps:get(public_key, Identity),
        private_key = maps:get(private_key, Identity),
        encryption_public_key = maps:get(encryption_public_key, Identity, undefined),
        encryption_private_key = maps:get(encryption_private_key, Identity, undefined)
    }.

%% @private
state_to_identity(#state{} = S) ->
    #{
        mri => S#state.mri,
        realm => S#state.realm,
        public_key => S#state.public_key,
        private_key => S#state.private_key,
        encryption_public_key => S#state.encryption_public_key,
        encryption_private_key => S#state.encryption_private_key
    }.

%% @private
generate_encryption_keypair() ->
    crypto:generate_key(ecdh, x25519).

build_mri(Realm, Owner, Name) ->
    iolist_to_binary([<<"mri:agent:">>, Realm, <<"/">>, Owner, <<"/">>, Name]).

generate_keypair() ->
    crypto:generate_key(eddsa, ed25519).

parse_mri_owner(MRI) ->
    case binary:split(MRI, <<"/">>, [global]) of
        [_, Owner, _Name] -> Owner;
        _ -> undefined
    end.

replace_mri_owner(MRI, NewOwner) ->
    case binary:split(MRI, <<"/">>, [global]) of
        [RealmPart, _OldOwner, Name] ->
            <<RealmPart/binary, "/", NewOwner/binary, "/", Name/binary>>;
        _ ->
            MRI
    end.

generate_name() ->
    Suffix = binary:encode_hex(crypto:strong_rand_bytes(2)),
    iolist_to_binary([<<"hecate-">>, string:lowercase(Suffix)]).

%% On startup, fix identities that joined a realm but still have "anonymous" owner.
maybe_fix_anonymous_owner(#state{mri = MRI} = State) when MRI =/= undefined ->
    case parse_mri_owner(MRI) of
        <<"anonymous">> ->
            case resolve_owner_from_memberships() of
                undefined -> State;
                Owner ->
                    NewMRI = replace_mri_owner(MRI, Owner),
                    Identity = #{
                        mri => NewMRI, realm => State#state.realm,
                        public_key => State#state.public_key,
                        private_key => State#state.private_key
                    },
                    save_identity(Identity),
                    logger:info("Fixed anonymous identity on startup: ~s -> ~s", [MRI, NewMRI]),
                    hecate_web_events:broadcast(identity_changed, #{mri => NewMRI}),
                    State#state{mri = NewMRI}
            end;
        _ ->
            State
    end;
maybe_fix_anonymous_owner(State) ->
    State.

%% Resolve owner from confirmed realm memberships (ETS projection).
resolve_owner_from_memberships() ->
    try project_realm_memberships_store:list_confirmed() of
        {ok, [#{oauth_account := Acct} | _]} when is_binary(Acct), byte_size(Acct) > 0 ->
            Acct;
        _ ->
            undefined
    catch
        _:_ -> undefined  %% ETS table may not exist yet during early boot
    end.
