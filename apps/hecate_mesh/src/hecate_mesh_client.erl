-module(hecate_mesh_client).
-behaviour(gen_server).

-export([start_link/0, get_client/0, get_status/0, publish/2, subscribe/2, unsubscribe/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to macula (excluded from PLT)
-dialyzer({nowarn_function, [handle_call/3, terminate/2, connect_to_mesh/1, try_connect_to_bootstrap/4]}).

-record(state, {
    client :: pid() | undefined,
    realm :: binary(),
    identity :: binary(),
    bootstrap :: [binary()],
    subscriptions :: #{reference() => binary()}
}).

%% API

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

get_status() ->
    gen_server:call(?MODULE, get_status).

%% Callbacks

init([]) ->
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    Identity = application:get_env(hecate, gateway_identity, <<"mri:agent:io.macula/hecate">>),
    Bootstrap = application:get_env(hecate, bootstrap, [<<"https://boot.macula.io:4433">>]),
    BootstrapBins = [ensure_binary(B) || B <- Bootstrap],
    logger:info("[hecate_mesh] Initializing mesh client (realm: ~s, identity: ~s)", [Realm, Identity]),
    self() ! connect,
    {ok, #state{
        client = undefined,
        realm = Realm,
        identity = Identity,
        bootstrap = BootstrapBins,
        subscriptions = #{}
    }}.

handle_call(get_client, _From, #state{client = Client} = State) ->
    {reply, {ok, Client}, State};

handle_call(get_status, _From, #state{client = Client, realm = Realm,
                                       identity = Identity,
                                       subscriptions = Subs} = State) ->
    Connected = is_pid(Client),
    Status = #{
        connected => Connected,
        realm => Realm,
        identity => Identity,
        subscription_count => maps:size(Subs)
    },
    {reply, {ok, Status}, State};

handle_call({publish, _Topic, _Payload}, _From, #state{client = undefined} = State) ->
    {reply, {error, not_connected}, State};
handle_call({publish, Topic, Payload}, _From, #state{client = Client} = State) ->
    Result = macula:publish(Client, Topic, Payload),
    {reply, Result, State};

handle_call({subscribe, _Topic, _Callback}, _From, #state{client = undefined} = State) ->
    {reply, {error, not_connected}, State};
handle_call({subscribe, Topic, CallbackPid}, _From, #state{client = Client, subscriptions = Subs} = State) ->
    CallbackFun = fun(EventData) ->
        CallbackPid ! {mesh_fact, Topic, EventData},
        ok
    end,
    case macula:subscribe(Client, Topic, CallbackFun) of
        {ok, SubRef} ->
            NewSubs = Subs#{SubRef => Topic},
            {reply, {ok, SubRef}, State#state{subscriptions = NewSubs}};
        {error, Reason} ->
            {reply, {error, Reason}, State}
    end;

handle_call({unsubscribe, _SubRef}, _From, #state{client = undefined} = State) ->
    {reply, {error, not_connected}, State};
handle_call({unsubscribe, SubRef}, _From, #state{client = Client, subscriptions = Subs} = State) ->
    Result = macula:unsubscribe(Client, SubRef),
    NewSubs = maps:remove(SubRef, Subs),
    {reply, Result, State#state{subscriptions = NewSubs}}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(connect, State) ->
    connect_to_mesh(State);

handle_info({reconnect, Delay}, State) ->
    timer:sleep(Delay),
    connect_to_mesh(State);

handle_info({'DOWN', _Ref, process, Pid, Reason}, #state{client = Pid} = State) ->
    logger:warning("[hecate_mesh] Connection lost: ~p, reconnecting...", [Reason]),
    self() ! {reconnect, 1000},
    {noreply, State#state{client = undefined, subscriptions = #{}}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{client = undefined}) ->
    ok;
terminate(_Reason, #state{client = Client}) ->
    macula:disconnect(Client),
    ok.

%% Internal

connect_to_mesh(#state{realm = Realm, identity = Identity, bootstrap = Bootstrap} = State) ->
    logger:info("[hecate_mesh] Connecting to mesh (realm: ~s)...", [Realm]),
    try_connect_to_bootstrap(Bootstrap, Realm, Identity, State).

try_connect_to_bootstrap([], _Realm, _Identity, State) ->
    logger:warning("[hecate_mesh] All bootstrap servers failed, retrying in 5s..."),
    self() ! {reconnect, 5000},
    {noreply, State};
try_connect_to_bootstrap([BootstrapUrl | Rest], Realm, Identity, State) ->
    Url = build_url(BootstrapUrl),
    Opts = #{
        realm => Realm,
        identity => Identity
    },
    logger:info("[hecate_mesh] Trying bootstrap: ~s", [Url]),
    case macula:connect(Url, Opts) of
        {ok, Client} ->
            erlang:monitor(process, Client),
            logger:info("[hecate_mesh] Connected to mesh via ~s", [Url]),
            {noreply, State#state{client = Client}};
        {error, Reason} ->
            logger:warning("[hecate_mesh] Failed to connect to ~s: ~p", [Url, Reason]),
            try_connect_to_bootstrap(Rest, Realm, Identity, State)
    end.

build_url(BootstrapUrl) when is_binary(BootstrapUrl) ->
    case BootstrapUrl of
        <<"quic://", _/binary>> -> BootstrapUrl;
        <<"https://", _/binary>> -> BootstrapUrl;
        _ -> <<"https://", BootstrapUrl/binary>>
    end.

ensure_binary(B) when is_binary(B) -> B;
ensure_binary(S) when is_list(S) -> list_to_binary(S).
