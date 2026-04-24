%%%-------------------------------------------------------------------
%%% @doc Hecate realm join session.
%%%
%%% Handles the OAuth-based realm join flow:
%%% 1. Generate join session (local + remote)
%%% 2. Open browser for OAuth login
%%% 3. Poll for confirmation (auto-confirmed on OAuth login)
%%% 4. Receive credentials on success
%%%
%%% Supports multiple realms and OAuth providers.
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
-export([init/1, handle_call/3, handle_cast/2, handle_continue/2,
         handle_info/2, terminate/2]).

-define(SERVER, ?MODULE).
-define(POLL_INTERVAL, 2000).
-define(SESSION_TTL, 600). %% 10 minutes

%% Hydrate cadence: probe every 1s for up to 120 attempts (2 min). If
%% realm_memberships_store never reports ready in that window we stay
%% idle rather than blocking the operator's UI on a dead boot.
-define(HYDRATE_FIRST_DELAY_MS,   500).
-define(HYDRATE_RETRY_DELAY_MS,  1000).
-define(HYDRATE_MAX_ATTEMPTS,     120).

%% Suppress supertype warnings (returns specific maps, spec uses map())
-dialyzer({nowarn_function, [do_start_joining/1, create_join_session/2, poll_session/2,
                             handle_join_confirmed/2, get_agent_info/0, state_to_map/1,
                             dispatch_initiate_membership/1, dispatch_confirm_membership/4,
                             resolve_oauth_account/1, extract_owner_from_mri/1,
                             update_identity_owner/1]}).

-record(state, {
    status :: idle | joining | joined | failed,
    session_id :: binary() | undefined,
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
    %% Hydrate happens in handle_continue so init/1 returns instantly.
    %% Reading realm_memberships_store from init used to block the
    %% entire hecate_sup boot by ~90s: the store itself can't spawn
    %% until hecate_sup finishes starting its children, but the child
    %% (realm_session) was waiting on the store's read via
    %% reckon_gater's retry loop. Defer the probe and drive it from
    %% handle_info — same outcome, no deadlock.
    {ok, #state{status = idle}, {continue, hydrate}}.

handle_continue(hydrate, State) ->
    schedule_hydrate_probe(1, ?HYDRATE_FIRST_DELAY_MS),
    {noreply, State}.

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
                joining_url = maps:get(joining_url, SessionData),
                expires_at = erlang:system_time(second) + ?SESSION_TTL,
                realm_url = RealmUrl,
                membership_id = MembershipId
            },
            erlang:send_after(?POLL_INTERVAL, self(), poll),
            hecate_web_events:broadcast(realm_join_status, #{status => joining}),
            {reply, {ok, state_to_map(NewState)}, NewState};
        {error, Reason} = Error ->
            hecate_web_events:broadcast(realm_join_status, #{status => failed}),
            {reply, Error, #state{status = failed, error = Reason}}
    end;

handle_call(get_status, _From, State) ->
    {reply, state_to_map(State), State};

handle_call(cancel, _From, _State) ->
    hecate_web_events:broadcast(realm_join_status, #{status => idle}),
    {reply, ok, #state{status = idle}}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({hydrate_probe, _Attempt}, #state{status = Status} = State)
  when Status =/= idle ->
    %% Someone joined (or started joining) before the probe fired —
    %% no point racing the hydrate against a live session.
    {noreply, State};
handle_info({hydrate_probe, Attempt}, State) ->
    Self = self(),
    spawn(fun() ->
        Self ! {hydrate_result, probe_live_membership(), Attempt}
    end),
    {noreply, State};

handle_info({hydrate_result, {hydrated, MembershipId, RealmUrl}, _Attempt},
            #state{status = idle} = State) ->
    logger:info("[realm_session] hydrated prior membership ~s (realm=~s)",
                [MembershipId, RealmUrl]),
    hecate_web_events:broadcast(realm_join_status, #{status => joined}),
    {noreply, State#state{status = joined,
                          membership_id = MembershipId,
                          realm_url = RealmUrl}};
handle_info({hydrate_result, empty, _Attempt}, #state{status = idle} = State) ->
    logger:info("[realm_session] no prior live membership — staying idle"),
    {noreply, State};
handle_info({hydrate_result, not_ready, Attempt},
            #state{status = idle} = State)
  when Attempt < ?HYDRATE_MAX_ATTEMPTS ->
    schedule_hydrate_probe(Attempt + 1, ?HYDRATE_RETRY_DELAY_MS),
    {noreply, State};
handle_info({hydrate_result, not_ready, _Attempt},
            #state{status = idle} = State) ->
    logger:warning("[realm_session] realm_memberships_store never became "
                   "readable within ~bs — staying idle",
                   [?HYDRATE_MAX_ATTEMPTS * ?HYDRATE_RETRY_DELAY_MS div 1000]),
    {noreply, State};
handle_info({hydrate_result, _Outcome, _Attempt}, State) ->
    %% State changed while the probe was in flight — drop the result.
    {noreply, State};

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
                    hecate_web_events:broadcast(realm_join_status, #{status => failed}),
                    {noreply, State#state{status = failed, error = expired}}
            end;
        {ok, #{status := <<"expired">>}} ->
            logger:info("Realm join session expired on server"),
            hecate_web_events:broadcast(realm_join_status, #{status => failed}),
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
    Url = <<RealmUrl/binary, "/api/v1/join/sessions">>,

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
            {ok, #{
                session_id => SessionId,
                joining_url => <<RealmUrl/binary, "/join/", SessionId/binary>>
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
    Url = <<RealmUrl/binary, "/api/v1/join/sessions/", SessionId/binary>>,

    case hackney:request(get, Url, [], <<>>, [with_body]) of
        {ok, 200, _RespHeaders, RespBody} ->
            Data = json:decode(RespBody),
            Status = maps:get(<<"status">>, Data),
            {ok, #{
                status => Status,
                refresh_token => maps:get(<<"refresh_token">>, Data, undefined),
                org_identity => maps:get(<<"org_identity">>, Data, undefined),
                cert_pem => maps:get(<<"cert_pem">>, Data, undefined),
                oauth_account => maps:get(<<"oauth_account">>, Data, undefined),
                oauth_provider => maps:get(<<"oauth_provider">>, Data, undefined)
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
    OAuthAccount = resolve_oauth_account(Data),
    OAuthProvider = maps:get(oauth_provider, Data, <<"github">>),

    %% Update node identity owner (anonymous -> actual username)
    update_identity_owner(OAuthAccount),

    %% Dispatch confirm_realm_membership command
    dispatch_confirm_membership(MembershipId, OAuthAccount, OAuthProvider, State#state.realm_url),

    %% Encrypt and store credentials in ReckonDB (replicated via Ra)
    dispatch_secure_credentials(MembershipId, #{
        refresh_token => maps:get(refresh_token, Data, undefined),
        org_identity => OrgIdentity,
        cert_pem => maps:get(cert_pem, Data, undefined)
    }),

    hecate_web_events:broadcast(realm_join_status, #{status => joined}),
    {noreply, State#state{status = joined}}.

-spec dispatch_initiate_membership(map()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch_initiate_membership(#{membership_id := MembershipId, realm_url := RealmUrl}) ->
    Now = erlang:system_time(millisecond),
    Cmd = initiate_realm_membership_v1:new(MembershipId, RealmUrl, Now),
    Result = maybe_initiate_realm_membership:dispatch(Cmd),
    case Result of
        {ok, Version, Events} ->
            logger:info("[realm_session] initiate_realm_membership dispatched "
                        "~s version=~p events=~p",
                        [MembershipId, Version, length(Events)]);
        {error, Reason} ->
            logger:warning("[realm_session] initiate_realm_membership FAILED "
                           "~s: ~p",
                           [MembershipId, Reason])
    end,
    Result.

-spec dispatch_confirm_membership(binary(), binary() | undefined, binary(), binary() | undefined) -> ok.
dispatch_confirm_membership(_MembershipId, undefined, _Provider, _RealmUrl) ->
    ok;
dispatch_confirm_membership(MembershipId, OAuthAccount, OAuthProvider, RealmUrl) when
    is_binary(OAuthAccount), byte_size(OAuthAccount) > 0 ->
    Now = erlang:system_time(millisecond),
    RealmId = derive_realm_id(RealmUrl),
    Cmd = confirm_realm_membership_v1:new(MembershipId, RealmId, OAuthAccount, OAuthProvider, Now),
    case maybe_confirm_realm_membership:dispatch(Cmd) of
        {ok, _Version, _Events} ->
            logger:info("Dispatched confirm_realm_membership for ~s@~s", [OAuthAccount, RealmId]);
        {error, Reason} ->
            logger:warning("Failed to dispatch confirm_realm_membership: ~p", [Reason])
    end,
    ok;
dispatch_confirm_membership(_, _, _, _) ->
    ok.

resolve_oauth_account(Data) ->
    case maps:get(oauth_account, Data, undefined) of
        Account when is_binary(Account), byte_size(Account) > 0 -> Account;
        _ -> extract_owner_from_mri(maps:get(org_identity, Data, undefined))
    end.

extract_owner_from_mri(undefined) -> undefined;
extract_owner_from_mri(MRI) when is_binary(MRI) ->
    %% "mri:org:io.macula/rgfaber" -> "rgfaber"
    case binary:split(MRI, <<"/">>, [global]) of
        [_, Owner | _] -> Owner;
        _ -> undefined
    end.

update_identity_owner(undefined) -> ok;
update_identity_owner(<<>>) -> ok;
update_identity_owner(Owner) ->
    case hecate_identity:update_owner(Owner) of
        ok -> ok;
        {error, already_claimed} -> ok;
        {error, Reason} ->
            logger:warning("Failed to update identity owner: ~p", [Reason]),
            ok
    end.

%% @private Encrypt credentials map and dispatch as event to ReckonDB.
-spec dispatch_secure_credentials(binary(), map()) -> ok.
dispatch_secure_credentials(MembershipId, CredsMap) ->
    %% Remove undefined values before encrypting
    CleanCreds = maps:filter(fun(_K, V) -> V =/= undefined end, CredsMap),
    Serialized = term_to_binary(CleanCreds),
    case hecate_crypto:encrypt(Serialized) of
        {ok, Encrypted} ->
            Cmd = secure_realm_credentials_v1:new(MembershipId, Encrypted),
            case maybe_secure_realm_credentials:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:info("Realm credentials secured for ~s", [MembershipId]);
                {error, Reason} ->
                    logger:warning("Failed to secure credentials: ~p", [Reason])
            end;
        {error, Reason} ->
            logger:error("Failed to encrypt credentials: ~p", [Reason])
    end,
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
        joining_url => S#state.joining_url
    },
    case S#state.expires_at of
        undefined -> Map;
        ExpiresAt ->
            Remaining = max(0, ExpiresAt - erlang:system_time(second)),
            Map#{expires_in => Remaining}
    end.

%% @private Three-state probe for the live-membership read.
%%
%% The hydrate loop needs to tell "store isn't up yet, try again" apart
%% from "store is up, you truly have no prior membership" — both used
%% to collapse into `none`, which meant every transient not-ready
%% dropped the operator back to the join page on boot.
-spec probe_live_membership() ->
    {hydrated, binary(), binary()} | empty | not_ready.
probe_live_membership() ->
    case is_store_ready(realm_memberships_store) of
        false -> not_ready;
        true  -> read_and_select()
    end.

-spec read_and_select() ->
    {hydrated, binary(), binary()} | empty | not_ready.
read_and_select() ->
    try evoq_event_store:read_all_global(realm_memberships_store, 0, 1000) of
        {ok, Events}        -> classify(select_live(Events));
        {error, no_workers} -> not_ready;
        {error, _}          -> not_ready
    catch
        %% reckon_gater can exit with no_workers after its own retry
        %% exhausts before the store's workers come online.
        _:_ -> not_ready
    end.

classify({ok, Id, RealmUrl}) -> {hydrated, Id, RealmUrl};
classify(none)               -> empty.

%% @private True once the store's manager is registered. Workers may
%% still be spawning, but the read path will then handle short-lived
%% no_workers as not_ready and we'll retry from handle_info.
-spec is_store_ready(atom()) -> boolean().
is_store_ready(StoreId) ->
    MgrName = reckon_db_naming:store_mgr_name(StoreId),
    is_pid(whereis(MgrName)).

-spec schedule_hydrate_probe(pos_integer(), non_neg_integer()) -> reference().
schedule_hydrate_probe(Attempt, DelayMs) ->
    erlang:send_after(DelayMs, self(), {hydrate_probe, Attempt}).

select_live(Events) ->
    %% Walk forward. For each MembershipId, track last-live status and
    %% the realm_url last seen in its initiated event (Hanko-era flow
    %% persists it there). At the end, return the most-recently-live
    %% membership by global event order.
    {Status, RealmUrls, LastLive} = lists:foldl(fun(E, {S, U, LL}) ->
        Type = event_type(E),
        Data = event_data(E),
        MId  = membership_id(Data),
        case {Type, MId} of
            {_, undefined} -> {S, U, LL};
            {<<"realm_membership_initiated_v1">>, MembId} ->
                RU = realm_url_field(Data),
                {maps:put(MembId, live, S), maps:put(MembId, RU, U), MembId};
            {<<"realm_membership_confirmed_v1">>, MembId} -> {maps:put(MembId, live, S),  U, MembId};
            {<<"realm_credentials_secured_v1">>,  MembId} -> {maps:put(MembId, live, S),  U, MembId};
            {<<"realm_membership_ended_v1">>,     MembId} -> {maps:put(MembId, ended, S), U, LL};
            {<<"realm_membership_resigned_v1">>,  MembId} -> {maps:put(MembId, ended, S), U, LL};
            {<<"realm_membership_revoked_v1">>,   MembId} -> {maps:put(MembId, ended, S), U, LL};
            _                                             -> {S, U, LL}
        end
    end, {#{}, #{}, undefined}, Events),
    case LastLive of
        undefined -> none;
        Id ->
            case maps:get(Id, Status, undefined) of
                live ->
                    RU = maps:get(Id, RealmUrls, undefined),
                    {ok, Id, default_if_undef(RU, default_realm_url())};
                _ ->
                    none
            end
    end.

default_if_undef(undefined, Default) -> Default;
default_if_undef(V, _) -> V.

membership_id(#{membership_id := Id})       -> Id;
membership_id(#{<<"membership_id">> := Id}) -> Id;
membership_id(_)                            -> undefined.

realm_url_field(#{realm_url := R})       -> R;
realm_url_field(#{<<"realm_url">> := R}) -> R;
realm_url_field(_)                       -> undefined.

event_type(#{event_type := T})       -> T;
event_type(#{<<"event_type">> := T}) -> T;
event_type({evoq_event, _, T, _, _, _, _, _, _, _, _, _}) -> T;
event_type(_) -> undefined.

event_data(#{data := D})       -> D;
event_data(#{<<"data">> := D}) -> D;
event_data({evoq_event, _, _, _, _, D, _, _, _, _, _, _}) -> D;
event_data(_) -> #{}.
