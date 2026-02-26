%%%-------------------------------------------------------------------
%%% @doc Hecate identity management.
%%%
%%% Handles MRI (Macula Resource Identifier) and Ed25519 keypair.
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
    agent_id/0,
    sign/1,
    verify/2,
    is_initialized/0,
    initialize/1
]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to public_key (excluded from PLT)
-dialyzer({nowarn_function, [handle_call/3]}).

-define(SERVER, ?MODULE).
-define(BUCKET, <<"identity">>).

-record(state, {
    mri :: binary() | undefined,
    realm :: binary() | undefined,
    public_key :: binary() | undefined,
    private_key :: binary() | undefined
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

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    State = case hecate_store:get(?BUCKET, <<"identity">>) of
        {ok, Identity} ->
            logger:info("Loaded identity: ~s", [maps:get(mri, Identity)]),
            #state{
                mri = maps:get(mri, Identity),
                realm = maps:get(realm, Identity),
                public_key = maps:get(public_key, Identity),
                private_key = maps:get(private_key, Identity)
            };
        not_found ->
            auto_initialize()
    end,
    {ok, State}.

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
    %% Generate new identity
    {PubKey, PrivKey} = generate_keypair(),
    
    Realm = maps:get(realm, Opts, <<"io.macula">>),
    Name = maps:get(name, Opts, generate_name()),
    
    %% Build MRI: mri:agent:realm/owner/name
    Owner = maps:get(owner, Opts, <<"anonymous">>),
    MRI = iolist_to_binary([
        <<"mri:agent:">>, Realm, <<"/">>, Owner, <<"/">>, Name
    ]),
    
    Identity = #{
        mri => MRI,
        realm => Realm,
        public_key => PubKey,
        private_key => PrivKey,
        created_at => erlang:system_time(second)
    },
    
    ok = hecate_store:put(?BUCKET, <<"identity">>, Identity),
    
    %% Log event
    ok = hecate_store:append_event(<<"identity">>, <<"identity_created">>, #{
        mri => MRI,
        realm => Realm
    }),
    
    logger:info("Created identity: ~s", [MRI]),
    
    NewState = #state{
        mri = MRI,
        realm = Realm,
        public_key = PubKey,
        private_key = PrivKey
    },
    {reply, ok, NewState};

handle_call({initialize, _Opts}, _From, State) ->
    {reply, {error, already_initialized}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%%===================================================================
%%% Internal functions
%%%===================================================================

auto_initialize() ->
    logger:info("No identity found — generating on first boot"),
    {PubKey, PrivKey} = generate_keypair(),
    Realm = <<"io.macula">>,
    Name = generate_name(),
    Owner = <<"anonymous">>,
    MRI = iolist_to_binary([
        <<"mri:agent:">>, Realm, <<"/">>, Owner, <<"/">>, Name
    ]),
    Identity = #{
        mri => MRI,
        realm => Realm,
        public_key => PubKey,
        private_key => PrivKey,
        created_at => erlang:system_time(second)
    },
    ok = hecate_store:put(?BUCKET, <<"identity">>, Identity),
    ok = hecate_store:append_event(<<"identity">>, <<"identity_created">>, #{
        mri => MRI,
        realm => Realm
    }),
    logger:info("Created identity: ~s", [MRI]),
    #state{
        mri = MRI,
        realm = Realm,
        public_key = PubKey,
        private_key = PrivKey
    }.

generate_keypair() ->
    {PubKey, PrivKey} = crypto:generate_key(eddsa, ed25519),
    {PubKey, PrivKey}.

generate_name() ->
    %% Generate a random name like "hecate-a1b2"
    Suffix = binary:encode_hex(crypto:strong_rand_bytes(2)),
    iolist_to_binary([<<"hecate-">>, string:lowercase(Suffix)]).
