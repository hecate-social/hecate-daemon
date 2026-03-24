-module(hecate_mesh_client).
-behaviour(gen_server).

-export([start_link/0, get_client/0, get_status/0, publish/2, subscribe/2, unsubscribe/1,
         discover_subscribers/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-dialyzer({nowarn_function, [handle_call/3, terminate/2, try_connect/3, get_node_id/1]}).

-define(INITIAL_BACKOFF_MS, 2000).
-define(MAX_BACKOFF_MS, 120000).

-record(state, {
    client :: pid() | undefined,
    realm :: binary(),
    identity :: binary(),
    bootstrap :: [binary()],
    subscriptions :: #{reference() => binary()},
    %% Durable subscription intents — survive reconnections.
    %% Key = Topic, Value = CallbackPid. Re-subscribed after each reconnect.
    sub_intents :: #{binary() => pid()},
    backoff_ms :: pos_integer(),
    connecting :: boolean()
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

discover_subscribers(Topic) ->
    gen_server:call(?MODULE, {discover_subscribers, Topic}).

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
        subscriptions = #{},
        sub_intents = #{},
        backoff_ms = ?INITIAL_BACKOFF_MS,
        connecting = false
    }}.

handle_call(get_client, _From, #state{client = Client} = State) ->
    {reply, {ok, Client}, State};

handle_call(get_status, _From, #state{client = Client, realm = Realm,
                                       identity = Identity, bootstrap = Bootstrap,
                                       subscriptions = Subs} = State) ->
    Connected = is_pid(Client),
    NodeId = case Connected of true -> get_node_id(Client); false -> null end,
    Status = #{
        connected => Connected,
        realm => Realm,
        identity => Identity,
        node_id => NodeId,
        subscriptions => lists:usort(maps:values(Subs)),
        subscription_count => maps:size(Subs),
        bootstrap => Bootstrap
    },
    {reply, {ok, Status}, State};

handle_call({discover_subscribers, _Topic}, _From, #state{client = undefined} = State) ->
    {reply, {error, not_connected}, State};
handle_call({discover_subscribers, Topic}, _From, #state{client = Client} = State) ->
    %% DHT find_value can timeout (10s gen_server:call inside macula).
    %% Catch the exit to avoid crashing the mesh client gen_server.
    Result = try macula:discover_subscribers(Client, Topic)
             catch exit:{timeout, _} -> {error, dht_timeout}
             end,
    {reply, Result, State};

handle_call({publish, _Topic, _Payload}, _From, #state{client = undefined} = State) ->
    {reply, {error, not_connected}, State};
handle_call({publish, Topic, Payload}, _From, #state{client = Client} = State) ->
    {reply, macula:publish(Client, Topic, Payload), State};

handle_call({subscribe, _Topic, _Callback}, _From, #state{client = undefined} = State) ->
    {reply, {error, not_connected}, State};
handle_call({subscribe, Topic, CallbackPid}, _From, #state{client = Client, subscriptions = Subs,
                                                          sub_intents = Intents} = State) ->
    CallbackFun = fun(EventData) ->
        CallbackPid ! {mesh_fact, Topic, EventData},
        ok
    end,
    case macula:subscribe(Client, Topic, CallbackFun) of
        {ok, SubRef} ->
            {reply, {ok, SubRef}, State#state{
                subscriptions = Subs#{SubRef => Topic},
                sub_intents = Intents#{Topic => CallbackPid}
            }};
        {error, Reason} ->
            {reply, {error, Reason}, State}
    end;

handle_call({unsubscribe, _SubRef}, _From, #state{client = undefined} = State) ->
    {reply, {error, not_connected}, State};
handle_call({unsubscribe, SubRef}, _From, #state{client = Client, subscriptions = Subs,
                                                  sub_intents = Intents} = State) ->
    %% Remove the intent for this topic so it won't be re-subscribed
    Topic = maps:get(SubRef, Subs, undefined),
    NewIntents = case Topic of
        undefined -> Intents;
        T -> maps:remove(T, Intents)
    end,
    Result = macula:unsubscribe(Client, SubRef),
    {reply, Result, State#state{subscriptions = maps:remove(SubRef, Subs),
                                sub_intents = NewIntents}}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Already connecting — ignore
handle_info(connect, #state{connecting = true} = State) ->
    {noreply, State};
%% Already connected — ignore
handle_info(connect, #state{client = Pid} = State) when is_pid(Pid) ->
    {noreply, State};
handle_info(connect, State) ->
    Self = self(),
    spawn(fun() ->
        Result = try_connect(State#state.bootstrap, State#state.realm, State#state.identity),
        Self ! {connect_result, Result}
    end),
    {noreply, State#state{connecting = true}};

handle_info({connect_result, {ok, Client}}, #state{sub_intents = Intents} = State) ->
    erlang:monitor(process, Client),
    logger:info("[hecate_mesh] Connected to mesh"),
    %% Re-subscribe to all durable intents
    NewSubs = resubscribe_intents(Client, Intents),
    {noreply, State#state{client = Client, subscriptions = NewSubs,
                          connecting = false, backoff_ms = ?INITIAL_BACKOFF_MS}};

handle_info({connect_result, {error, Reason}}, #state{backoff_ms = Backoff} = State) ->
    logger:warning("[hecate_mesh] Connection failed: ~p, retrying in ~.1fs", [Reason, Backoff / 1000]),
    erlang:send_after(Backoff, self(), connect),
    {noreply, State#state{connecting = false, backoff_ms = min(Backoff * 2, ?MAX_BACKOFF_MS)}};

handle_info({'DOWN', _Ref, process, Pid, Reason}, #state{client = Pid} = State) ->
    logger:warning("[hecate_mesh] Connection lost: ~p, reconnecting (~b intents to restore)...",
                   [Reason, maps:size(State#state.sub_intents)]),
    erlang:send_after(?INITIAL_BACKOFF_MS, self(), connect),
    %% Clear active subscriptions (refs are dead) but KEEP intents for re-subscribe
    {noreply, State#state{client = undefined, subscriptions = #{}, connecting = false,
                          backoff_ms = ?INITIAL_BACKOFF_MS}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{client = undefined}) -> ok;
terminate(_Reason, #state{client = Client}) ->
    macula:disconnect(Client),
    ok.

%% Internal

%% @private Re-subscribe all durable intents after reconnection.
resubscribe_intents(Client, Intents) ->
    maps:fold(fun(Topic, CallbackPid, Acc) ->
        CallbackFun = fun(EventData) ->
            CallbackPid ! {mesh_fact, Topic, EventData},
            ok
        end,
        case macula:subscribe(Client, Topic, CallbackFun) of
            {ok, SubRef} ->
                logger:info("[hecate_mesh] Re-subscribed to ~s", [Topic]),
                Acc#{SubRef => Topic};
            {error, Reason} ->
                logger:warning("[hecate_mesh] Failed to re-subscribe to ~s: ~p", [Topic, Reason]),
                Acc
        end
    end, #{}, Intents).

try_connect([], _Realm, _Identity) ->
    {error, all_bootstrap_servers_failed};
try_connect([BootstrapUrl | Rest], Realm, Identity) ->
    Url = build_url(BootstrapUrl),
    logger:info("[hecate_mesh] Trying bootstrap: ~s", [Url]),
    case macula:connect(Url, #{realm => Realm, identity => Identity}) of
        {ok, Client} ->
            logger:info("[hecate_mesh] Connected via ~s", [Url]),
            {ok, Client};
        {error, Reason} ->
            logger:warning("[hecate_mesh] Failed to connect to ~s: ~p", [Url, Reason]),
            try_connect(Rest, Realm, Identity)
    end.

build_url(<<"quic://", _/binary>> = Url) -> Url;
build_url(<<"https://", _/binary>> = Url) -> Url;
build_url(Url) -> <<"https://", Url/binary>>.

ensure_binary(B) when is_binary(B) -> B;
ensure_binary(S) when is_list(S) -> list_to_binary(S).

get_node_id(Client) ->
    try
        Self = self(),
        Ref = make_ref(),
        Pid = spawn(fun() ->
            Result = try macula:get_node_id(Client) catch _:_ -> {error, failed} end,
            Self ! {Ref, Result}
        end),
        receive
            {Ref, {ok, NodeIdBin}} when is_binary(NodeIdBin) -> binary:encode_hex(NodeIdBin);
            {Ref, NodeIdBin} when is_binary(NodeIdBin) -> binary:encode_hex(NodeIdBin);
            {Ref, _} -> null
        after 2000 ->
            exit(Pid, kill), null
        end
    catch _:_ -> null
    end.
