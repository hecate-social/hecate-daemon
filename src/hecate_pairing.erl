%%%-------------------------------------------------------------------
%%% @doc Hecate device pairing.
%%%
%%% Handles the QR code pairing flow:
%%% 1. Generate pairing session (local + remote)
%%% 2. Display QR code with confirmation code
%%% 3. Poll for confirmation
%%% 4. Receive certificate on success
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_pairing).
-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([
    start_pairing/0,
    get_status/0,
    cancel/0
]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(SERVER, ?MODULE).
-define(POLL_INTERVAL, 2000).
-define(SESSION_TTL, 600). %% 10 minutes

%% Suppress supertype warnings (returns specific maps, spec uses map())
-dialyzer({nowarn_function, [do_start_pairing/0, create_pairing_session/1, poll_session/1,
                             handle_pairing_confirmed/2, get_agent_info/0, state_to_map/1]}).

-record(state, {
    status :: idle | pairing | paired | failed,
    session_id :: binary() | undefined,
    confirm_code :: binary() | undefined,
    pairing_url :: binary() | undefined,
    expires_at :: integer() | undefined,
    error :: term() | undefined
}).

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec start_pairing() -> {ok, map()} | {error, term()}.
start_pairing() ->
    gen_server:call(?SERVER, start_pairing, 30000).

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

handle_call(start_pairing, _From, #state{status = pairing} = State) ->
    %% Already pairing, return current session
    {reply, {ok, state_to_map(State)}, State};

handle_call(start_pairing, _From, State) ->
    case do_start_pairing() of
        {ok, SessionData} ->
            NewState = #state{
                status = pairing,
                session_id = maps:get(session_id, SessionData),
                confirm_code = maps:get(confirm_code, SessionData),
                pairing_url = maps:get(pairing_url, SessionData),
                expires_at = erlang:system_time(second) + ?SESSION_TTL
            },
            %% Start polling
            erlang:send_after(?POLL_INTERVAL, self(), poll),
            %% Log event
            hecate_store:append_event(<<"pairing">>, <<"pairing_started">>, #{
                session_id => NewState#state.session_id
            }),
            {reply, {ok, state_to_map(NewState)}, NewState};
        {error, Reason} = Error ->
            {reply, Error, State#state{status = failed, error = Reason}}
    end;

handle_call(get_status, _From, State) ->
    {reply, state_to_map(State), State};

handle_call(cancel, _From, _State) ->
    {reply, ok, #state{status = idle}}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(poll, #state{status = pairing, session_id = SessionId} = State) ->
    case poll_session(SessionId) of
        {ok, #{status := <<"confirmed">>} = Data} ->
            %% Pairing confirmed!
            handle_pairing_confirmed(Data, State);
        {ok, #{status := <<"pending">>}} ->
            %% Still waiting, poll again
            Now = erlang:system_time(second),
            case State#state.expires_at > Now of
                true ->
                    erlang:send_after(?POLL_INTERVAL, self(), poll),
                    {noreply, State};
                false ->
                    %% Expired
                    logger:info("Pairing session expired"),
                    {noreply, State#state{status = failed, error = expired}}
            end;
        {ok, #{status := <<"expired">>}} ->
            logger:info("Pairing session expired on server"),
            {noreply, State#state{status = failed, error = expired}};
        {error, Reason} ->
            logger:warning("Pairing poll failed: ~p", [Reason]),
            %% Retry on transient errors
            erlang:send_after(?POLL_INTERVAL * 2, self(), poll),
            {noreply, State}
    end;

handle_info(poll, State) ->
    %% Not in pairing state, ignore
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec do_start_pairing() -> {ok, map()} | {error, term()}.
do_start_pairing() ->
    %% Get our public key
    case hecate_identity:get_public_key() of
        {ok, PubKey} ->
            PubKeyB64 = base64:encode(PubKey),
            create_pairing_session(PubKeyB64);
        not_initialized ->
            {error, identity_not_initialized}
    end.

-spec create_pairing_session(binary()) -> {ok, map()} | {error, term()}.
create_pairing_session(PubKeyB64) ->
    RealmUrl = get_realm_url(),
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
                pairing_url => <<RealmUrl/binary, "/pair/", SessionId/binary>>
            }};
        {ok, Status, _RespHeaders, RespBody} ->
            logger:error("Failed to create pairing session: ~p ~s", [Status, RespBody]),
            {error, {http_error, Status}};
        {error, Reason} ->
            logger:error("Failed to create pairing session: ~p", [Reason]),
            {error, Reason}
    end.

-spec poll_session(binary()) -> {ok, map()} | {error, term()}.
poll_session(SessionId) ->
    RealmUrl = get_realm_url(),
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

-spec handle_pairing_confirmed(map(), #state{}) -> {noreply, #state{}}.
handle_pairing_confirmed(Data, State) ->
    logger:info("Pairing confirmed!"),
    
    %% Store the refresh token
    case maps:get(refresh_token, Data, undefined) of
        undefined -> ok;
        Token ->
            hecate_store:put(<<"auth">>, <<"refresh_token">>, Token)
    end,
    
    %% Store the org identity
    case maps:get(org_identity, Data, undefined) of
        undefined -> ok;
        OrgId ->
            hecate_store:put(<<"auth">>, <<"org_identity">>, OrgId)
    end,
    
    %% Store the certificate if provided
    case maps:get(cert_pem, Data, undefined) of
        undefined -> ok;
        CertPem ->
            hecate_store:put(<<"auth">>, <<"cert_pem">>, CertPem)
    end,
    
    %% Log event
    hecate_store:append_event(<<"pairing">>, <<"pairing_confirmed">>, #{
        session_id => State#state.session_id,
        org_identity => maps:get(org_identity, Data, undefined)
    }),
    
    %% TODO: Trigger mesh reconnection with new credentials
    
    {noreply, State#state{status = paired}}.

-spec get_realm_url() -> binary().
get_realm_url() ->
    case application:get_env(hecate, realm_url) of
        {ok, Url} when is_binary(Url) -> Url;
        {ok, Url} when is_list(Url) -> list_to_binary(Url);
        _ -> <<"https://macula.io">>
    end.

-spec get_agent_info() -> map().
get_agent_info() ->
    #{
        hostname => list_to_binary(net_adm:localhost()),
        os => os_type_to_binary(),
        version => <<"0.1.0">>
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
        pairing_url => S#state.pairing_url
    },
    case S#state.expires_at of
        undefined -> Map;
        ExpiresAt -> 
            Remaining = max(0, ExpiresAt - erlang:system_time(second)),
            Map#{expires_in => Remaining}
    end.
