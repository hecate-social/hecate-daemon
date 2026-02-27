%%%-------------------------------------------------------------------
%%% @doc Hecate realm join session.
%%%
%%% Handles the OAuth-based realm join flow:
%%% 1. Generate join session (local + remote)
%%% 2. Display confirmation code
%%% 3. Poll for confirmation
%%% 4. Receive credentials on success
%%%
%%% Replaces hecate_pairing — supports multiple realms and OAuth providers.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_realm_session).
-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([
    start_joining/1,
    get_status/0,
    cancel/0
]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(SERVER, ?MODULE).
-define(POLL_INTERVAL, 2000).
-define(SESSION_TTL, 600). %% 10 minutes

%% Suppress supertype warnings (returns specific maps, spec uses map())
-dialyzer({nowarn_function, [do_start_joining/1, create_join_session/2, poll_session/2,
                             handle_join_confirmed/2, get_agent_info/0, state_to_map/1,
                             dispatch_initiate_membership/1, dispatch_confirm_membership/3]}).

-record(state, {
    status :: idle | joining | joined | failed,
    session_id :: binary() | undefined,
    confirm_code :: binary() | undefined,
    joining_url :: binary() | undefined,
    expires_at :: integer() | undefined,
    realm_url :: binary() | undefined,
    membership_id :: binary() | undefined,
    error :: term() | undefined
}).

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec start_joining(map()) -> {ok, map()} | {error, term()}.
start_joining(#{realm_url := _} = Opts) ->
    gen_server:call(?SERVER, {start_joining, Opts}, 30000).

-spec get_status() -> map().
get_status() ->
    gen_server:call(?SERVER, get_status).

-spec cancel() -> ok.
cancel() ->
    gen_server:call(?SERVER, cancel).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    {ok, #state{status = idle}}.

handle_call({start_joining, _Opts}, _From, #state{status = joining} = State) ->
    %% Already joining, return current session
    {reply, {ok, state_to_map(State)}, State};

handle_call({start_joining, Opts}, _From, _State) ->
    RealmUrl = maps:get(realm_url, Opts, default_realm_url()),
    case do_start_joining(RealmUrl) of
        {ok, SessionData, MembershipId} ->
            NewState = #state{
                status = joining,
                session_id = maps:get(session_id, SessionData),
                confirm_code = maps:get(confirm_code, SessionData),
                joining_url = maps:get(joining_url, SessionData),
                expires_at = erlang:system_time(second) + ?SESSION_TTL,
                realm_url = RealmUrl,
                membership_id = MembershipId
            },
            erlang:send_after(?POLL_INTERVAL, self(), poll),
            {reply, {ok, state_to_map(NewState)}, NewState};
        {error, Reason} = Error ->
            {reply, Error, #state{status = failed, error = Reason}}
    end;

handle_call(get_status, _From, State) ->
    {reply, state_to_map(State), State};

handle_call(cancel, _From, _State) ->
    {reply, ok, #state{status = idle}}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(poll, #state{status = joining, session_id = SessionId, realm_url = RealmUrl} = State) ->
    case poll_session(RealmUrl, SessionId) of
        {ok, #{status := <<"confirmed">>} = Data} ->
            handle_join_confirmed(Data, State);
        {ok, #{status := <<"pending">>}} ->
            Now = erlang:system_time(second),
            case State#state.expires_at > Now of
                true ->
                    erlang:send_after(?POLL_INTERVAL, self(), poll),
                    {noreply, State};
                false ->
                    logger:info("Realm join session expired"),
                    {noreply, State#state{status = failed, error = expired}}
            end;
        {ok, #{status := <<"expired">>}} ->
            logger:info("Realm join session expired on server"),
            {noreply, State#state{status = failed, error = expired}};
        {error, Reason} ->
            logger:warning("Realm join poll failed: ~p", [Reason]),
            erlang:send_after(?POLL_INTERVAL * 2, self(), poll),
            {noreply, State}
    end;

handle_info(poll, State) ->
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec do_start_joining(binary()) -> {ok, map(), binary()} | {error, term()}.
do_start_joining(RealmUrl) ->
    case hecate_identity:get_public_key() of
        {ok, PubKey} ->
            PubKeyB64 = base64:encode(PubKey),
            MembershipId = generate_membership_id(),
            %% Dispatch initiate_realm_membership command
            case dispatch_initiate_membership(#{
                membership_id => MembershipId,
                realm_url => RealmUrl
            }) of
                {ok, _Version, _Events} ->
                    case create_join_session(RealmUrl, PubKeyB64) of
                        {ok, SessionData} ->
                            {ok, SessionData, MembershipId};
                        {error, _} = Err ->
                            Err
                    end;
                {error, _} = Err ->
                    Err
            end;
        not_initialized ->
            {error, identity_not_initialized}
    end.

-spec create_join_session(binary(), binary()) -> {ok, map()} | {error, term()}.
create_join_session(RealmUrl, PubKeyB64) ->
    Url = <<RealmUrl/binary, "/api/v1/pairing/sessions">>,

    {ok, MRI} = hecate_identity:get_mri(),

    Body = json:encode(#{
        public_key => PubKeyB64,
        agent_mri => MRI,
        agent_info => get_agent_info()
    }),

    Headers = [{<<"content-type">>, <<"application/json">>}],

    case hackney:request(post, Url, Headers, Body, [with_body]) of
        {ok, 201, _RespHeaders, RespBody} ->
            Data = json:decode(RespBody),
            SessionId = maps:get(<<"session_id">>, Data),
            ConfirmCode = maps:get(<<"confirm_code">>, Data),
            {ok, #{
                session_id => SessionId,
                confirm_code => ConfirmCode,
                joining_url => <<RealmUrl/binary, "/pair/", SessionId/binary,
                                  "?code=", ConfirmCode/binary>>
            }};
        {ok, Status, _RespHeaders, RespBody} ->
            logger:error("Failed to create join session: ~p ~s", [Status, RespBody]),
            {error, {http_error, Status}};
        {error, Reason} ->
            logger:error("Failed to create join session: ~p", [Reason]),
            {error, Reason}
    end.

-spec poll_session(binary(), binary()) -> {ok, map()} | {error, term()}.
poll_session(RealmUrl, SessionId) ->
    Url = <<RealmUrl/binary, "/api/v1/pairing/sessions/", SessionId/binary>>,

    case hackney:request(get, Url, [], <<>>, [with_body]) of
        {ok, 200, _RespHeaders, RespBody} ->
            Data = json:decode(RespBody),
            Status = maps:get(<<"status">>, Data),
            {ok, #{
                status => Status,
                refresh_token => maps:get(<<"refresh_token">>, Data, undefined),
                org_identity => maps:get(<<"org_identity">>, Data, undefined),
                cert_pem => maps:get(<<"cert_pem">>, Data, undefined)
            }};
        {ok, 404, _RespHeaders, _RespBody} ->
            {ok, #{status => <<"expired">>}};
        {ok, Status, _RespHeaders, RespBody} ->
            logger:warning("Poll session failed: ~p ~s", [Status, RespBody]),
            {error, {http_error, Status}};
        {error, Reason} ->
            {error, Reason}
    end.

-spec handle_join_confirmed(map(), #state{}) -> {noreply, #state{}}.
handle_join_confirmed(Data, #state{membership_id = MembershipId} = State) ->
    logger:info("Realm join confirmed!"),

    OrgIdentity = maps:get(org_identity, Data, undefined),

    %% Store credentials keyed by membership ID
    store_credential(MembershipId, <<"refresh_token">>, maps:get(refresh_token, Data, undefined)),
    store_credential(MembershipId, <<"org_identity">>, OrgIdentity),
    store_credential(MembershipId, <<"cert_pem">>, maps:get(cert_pem, Data, undefined)),

    %% Dispatch confirm_realm_membership command
    dispatch_confirm_membership(MembershipId, OrgIdentity, State#state.realm_url),

    {noreply, State#state{status = joined}}.

-spec dispatch_initiate_membership(map()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch_initiate_membership(#{membership_id := MembershipId, realm_url := RealmUrl}) ->
    Now = erlang:system_time(millisecond),
    Cmd = initiate_realm_membership_v1:new(MembershipId, RealmUrl, Now),
    maybe_initiate_realm_membership:dispatch(Cmd).

-spec dispatch_confirm_membership(binary(), binary() | undefined, binary() | undefined) -> ok.
dispatch_confirm_membership(_MembershipId, undefined, _RealmUrl) ->
    ok;
dispatch_confirm_membership(MembershipId, OAuthAccount, RealmUrl) when
    is_binary(OAuthAccount), byte_size(OAuthAccount) > 0 ->
    Now = erlang:system_time(millisecond),
    %% Derive realm_id from realm_url (e.g. "https://macula.io" -> "io.macula")
    RealmId = derive_realm_id(RealmUrl),
    Cmd = confirm_realm_membership_v1:new(MembershipId, RealmId, OAuthAccount, <<"github">>, Now),
    case maybe_confirm_realm_membership:dispatch(Cmd) of
        {ok, _Version, _Events} ->
            logger:info("Dispatched confirm_realm_membership for ~s@~s", [OAuthAccount, RealmId]);
        {error, Reason} ->
            logger:warning("Failed to dispatch confirm_realm_membership: ~p", [Reason])
    end,
    ok;
dispatch_confirm_membership(_, _, _) ->
    ok.

-spec store_credential(binary(), binary(), binary() | undefined) -> ok.
store_credential(_MembershipId, _Key, undefined) ->
    ok;
store_credential(MembershipId, Key, Value) ->
    StorageKey = <<Key/binary, ":", MembershipId/binary>>,
    hecate_store:put(<<"auth">>, StorageKey, Value),
    ok.

-spec generate_membership_id() -> binary().
generate_membership_id() ->
    Bytes = crypto:strong_rand_bytes(16),
    Hex = binary:encode_hex(Bytes, lowercase),
    <<A:8/binary, B:4/binary, C:4/binary, D:4/binary, E:12/binary>> = Hex,
    <<A/binary, "-", B/binary, "-", C/binary, "-", D/binary, "-", E/binary>>.

-spec derive_realm_id(binary() | undefined) -> binary().
derive_realm_id(undefined) ->
    <<"io.macula">>;
derive_realm_id(RealmUrl) ->
    %% Extract host, reverse domain parts: "https://macula.io" -> "io.macula"
    case uri_string:parse(RealmUrl) of
        #{host := Host} ->
            Parts = binary:split(Host, <<".">>, [global]),
            iolist_to_binary(lists:join(<<".">> , lists:reverse(Parts)));
        _ ->
            <<"io.macula">>
    end.

-spec default_realm_url() -> binary().
default_realm_url() ->
    case application:get_env(hecate, realm_url) of
        {ok, Url} when is_binary(Url) -> Url;
        {ok, Url} when is_list(Url) -> list_to_binary(Url);
        _ -> <<"https://macula.io">>
    end.

-spec get_agent_info() -> map().
get_agent_info() ->
    {ok, Vsn} = application:get_key(hecate, vsn),
    #{
        hostname => shared_host:hostname(),
        os => os_type_to_binary(),
        version => list_to_binary(Vsn)
    }.

-spec os_type_to_binary() -> binary().
os_type_to_binary() ->
    {OsFamily, OsName} = os:type(),
    iolist_to_binary([atom_to_list(OsFamily), "/", atom_to_list(OsName)]).

-spec state_to_map(#state{}) -> map().
state_to_map(#state{} = S) ->
    Map = #{
        status => S#state.status,
        session_id => S#state.session_id,
        confirm_code => S#state.confirm_code,
        joining_url => S#state.joining_url
    },
    case S#state.expires_at of
        undefined -> Map;
        ExpiresAt ->
            Remaining = max(0, ExpiresAt - erlang:system_time(second)),
            Map#{expires_in => Remaining}
    end.
