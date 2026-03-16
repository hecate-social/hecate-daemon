-module(hecate_mesh_client).
-behaviour(gen_server).

-export([start_link/0, get_client/0, get_status/0, publish/2, subscribe/2, unsubscribe/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to macula (excluded from PLT)
-dialyzer({nowarn_function, [handle_call/3, terminate/2, spawn_connect/1, try_connect/3]}).

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
    spawn_connect(State),
    {noreply, State};

handle_info({reconnect, Delay}, State) ->
    erlang:send_after(Delay, self(), connect),
    {noreply, State};

handle_info({connected, Client}, State) ->
    erlang:monitor(process, Client),
    logger:info("[hecate_mesh] Connected to mesh"),
    {noreply, State#state{client = Client}};

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

%% Spawn connection attempt so the gen_server remains responsive to calls
%% (e.g., subscribe) while the QUIC handshake is in progress.
spawn_connect(#state{realm = Realm, identity = Identity, bootstrap = Bootstrap}) ->
    Self = self(),
    spawn(fun() ->
        logger:info("[hecate_mesh] Connecting to mesh (realm: ~s)...", [Realm]),
        case try_connect(Bootstrap, Realm, Identity) of
            {ok, Client} ->
                Self ! {connected, Client};
            {error, _} ->
                Self ! {reconnect, 5000}
        end
    end).

try_connect([], _Realm, _Identity) ->
    logger:warning("[hecate_mesh] All bootstrap servers failed, retrying in 5s..."),
    {error, all_failed};
try_connect([BootstrapUrl | Rest], Realm, Identity) ->
    Url = build_url(BootstrapUrl),
    Opts = #{
        realm => Realm,
        identity => Identity
    },
    logger:info("[hecate_mesh] Trying bootstrap: ~s", [Url]),
    case connect_with_timeout(Url, Opts, 15000) of
        {ok, Client} ->
            logger:info("[hecate_mesh] Connected to mesh via ~s", [Url]),
            {ok, Client};
        {error, Reason} ->
            logger:warning("[hecate_mesh] Failed to connect to ~s: ~p", [Url, Reason]),
            try_connect(Rest, Realm, Identity)
    end.

%% macula:connect/2 can block indefinitely if the QUIC handshake is slow
%% or macula_peer:init times out internally. Wrap with a timeout.
connect_with_timeout(Url, Opts, Timeout) ->
    Self = self(),
    Ref = make_ref(),
    Pid = spawn(fun() ->
        Result = try
            macula:connect(Url, Opts)
        catch
            _:Reason -> {error, {crashed, Reason}}
        end,
        Self ! {Ref, Result}
    end),
    receive
        {Ref, Result} -> Result
    after Timeout ->
        exit(Pid, kill),
        {error, connect_timeout}
    end.

build_url(BootstrapUrl) when is_binary(BootstrapUrl) ->
    case BootstrapUrl of
        <<"quic://", _/binary>> -> BootstrapUrl;
        <<"https://", _/binary>> -> BootstrapUrl;
        _ -> <<"https://", BootstrapUrl/binary>>
    end.

ensure_binary(B) when is_binary(B) -> B;
ensure_binary(S) when is_list(S) -> list_to_binary(S).
