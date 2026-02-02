-module(hecate_mesh_client).
-behaviour(gen_server).

-export([start_link/0, get_client/0, publish/2, subscribe/2, unsubscribe/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to macula (excluded from PLT)
-dialyzer({nowarn_function, [handle_call/3, terminate/2, connect_to_mesh/3]}).

-record(state, {
    client :: pid() | undefined,
    realm :: binary(),
    identity :: binary(),
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

%% Callbacks

init([]) ->
    Realm = application:get_env(hecate_mesh, realm, <<"io.macula">>),
    Identity = application:get_env(hecate_mesh, agent_identity, <<"mri:agent:io.macula/hecate">>),
    self() ! connect,
    {ok, #state{
        client = undefined,
        realm = Realm,
        identity = Identity,
        subscriptions = #{}
    }}.

handle_call(get_client, _From, #state{client = Client} = State) ->
    {reply, {ok, Client}, State};

handle_call({publish, _Topic, _Payload}, _From, #state{client = undefined} = State) ->
    {reply, {error, not_connected}, State};
handle_call({publish, Topic, Payload}, _From, #state{client = Client} = State) ->
    Result = macula:publish(Client, Topic, Payload),
    {reply, Result, State};

handle_call({subscribe, _Topic, _Callback}, _From, #state{client = undefined} = State) ->
    {reply, {error, not_connected}, State};
handle_call({subscribe, Topic, Callback}, _From, #state{client = Client, subscriptions = Subs} = State) ->
    case macula:subscribe(Client, Topic, Callback) of
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

handle_info(connect, #state{realm = Realm, identity = Identity} = State) ->
    connect_to_mesh(Realm, Identity, State);

handle_info({reconnect, Delay}, #state{realm = Realm, identity = Identity} = State) ->
    timer:sleep(Delay),
    connect_to_mesh(Realm, Identity, State);

handle_info({'DOWN', _Ref, process, Pid, Reason}, #state{client = Pid} = State) ->
    io:format("[hecate_mesh] Connection lost: ~p, reconnecting...~n", [Reason]),
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

connect_to_mesh(Realm, Identity, State) ->
    io:format("[hecate_mesh] Connecting to mesh (realm: ~s)...~n", [Realm]),
    case macula:connect_local(#{realm => Realm, identity => Identity}) of
        {ok, Client} ->
            erlang:monitor(process, Client),
            io:format("[hecate_mesh] Connected to mesh~n"),
            {noreply, State#state{client = Client}};
        {error, Reason} ->
            io:format("[hecate_mesh] Connection failed: ~p, retrying in 5s...~n", [Reason]),
            self() ! {reconnect, 5000},
            {noreply, State}
    end.
