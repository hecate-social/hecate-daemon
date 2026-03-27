%%%-------------------------------------------------------------------
%%% @doc Hecate mesh client — connects to the relay server.
%%%
%%% Thin wrapper around macula_relay_client. The relay client handles
%%% QUIC connection, reconnection, and subscription replay internally.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_mesh_client).
-behaviour(gen_server).

-export([start_link/0, get_client/0, get_status/0, publish/2, subscribe/2,
         unsubscribe/1, discover_subscribers/1, advertise/2, call/3, call/4]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    client :: pid() | undefined,
    realm :: binary(),
    identity :: binary(),
    relays :: [binary()]
}).

%%====================================================================
%% API
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

get_client() ->
    gen_server:call(?MODULE, get_client).

publish(Topic, Payload) ->
    gen_server:call(?MODULE, {publish, Topic, Payload}).

subscribe(Topic, Callback) ->
    gen_server:call(?MODULE, {subscribe, Topic, Callback}).

unsubscribe(SubRef) ->
    gen_server:call(?MODULE, {unsubscribe, SubRef}).

advertise(Procedure, Handler) ->
    gen_server:call(?MODULE, {advertise, Procedure, Handler}).

call(Procedure, Args, Timeout) ->
    gen_server:call(?MODULE, {rpc_call, Procedure, Args, Timeout}, Timeout + 1000).

call(Procedure, Args, _Opts, Timeout) ->
    call(Procedure, Args, Timeout).

get_status() ->
    gen_server:call(?MODULE, get_status).

discover_subscribers(_Topic) ->
    {ok, []}.

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    Identity = application:get_env(hecate, gateway_identity, <<"mri:agent:io.macula/hecate">>),
    Bootstrap = case os:getenv("MACULA_RELAYS") of
        false -> application:get_env(hecate, bootstrap,
                     [<<"https://relay00.macula.io:4433">>]);
        EnvStr -> [list_to_binary(string:trim(U))
                   || U <- string:split(EnvStr, ",", all),
                      string:trim(U) =/= ""]
    end,
    Relays = [ensure_binary(R) || R <- Bootstrap],

    logger:info("[hecate_mesh] Starting relay client (realm: ~s, relays: ~p)", [Realm, Relays]),

    {ok, Client} = macula_relay_client:start_link(#{
        relays => Relays,
        realm => Realm,
        identity => Identity
    }),

    logger:info("[hecate_mesh] Relay client started"),

    {ok, #state{
        client = Client,
        realm = Realm,
        identity = Identity,
        relays = Relays
    }}.

handle_call(get_client, _From, #state{client = Client} = State) ->
    {reply, {ok, Client}, State};

handle_call(get_status, _From, #state{client = Client, realm = Realm,
                                       identity = Identity, relays = Relays} = State) ->
    Status = #{
        connected => is_pid(Client),
        realm => Realm,
        identity => Identity,
        relays => Relays,
        mode => relay
    },
    {reply, {ok, Status}, State};

handle_call({publish, Topic, Payload}, _From, #state{client = Client} = State) ->
    macula_relay_client:publish(Client, Topic, Payload),
    {reply, ok, State};

handle_call({subscribe, Topic, Callback}, _From, #state{client = Client} = State) ->
    Result = macula_relay_client:subscribe(Client, Topic, Callback),
    {reply, Result, State};

handle_call({unsubscribe, SubRef}, _From, #state{client = Client} = State) ->
    Result = macula_relay_client:unsubscribe(Client, SubRef),
    {reply, Result, State};

handle_call({advertise, Procedure, Handler}, _From, #state{client = Client} = State) ->
    Result = macula_relay_client:advertise(Client, Procedure, Handler),
    {reply, Result, State};

handle_call({rpc_call, Procedure, Args, Timeout}, _From, #state{client = Client} = State) ->
    Result = macula_relay_client:call(Client, Procedure, Args, Timeout),
    {reply, Result, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{client = Client}) ->
    catch macula_relay_client:stop(Client),
    ok.

%%====================================================================
%% Internal
%%====================================================================

ensure_binary(B) when is_binary(B) -> B;
ensure_binary(S) when is_list(S) -> list_to_binary(S).
