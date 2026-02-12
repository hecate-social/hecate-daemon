%%% @doc Mesh listener: Node connections.
%%%
%%% Subscribes to hecate.node.connected and hecate.node.disconnected
%%% mesh facts. Projects to my_connections table in the node lifecycle
%%% read model.
-module(mesh_connection_listener).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {subscriptions :: [reference() | undefined]}).

%% API

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Callbacks

init([]) ->
    self() ! subscribe,
    {ok, #state{subscriptions = []}}.

handle_call(_Req, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(subscribe, State) ->
    Subs = [subscribe_to_topic(T) || T <- topics()],
    {noreply, State#state{subscriptions = Subs}};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscriptions = Subs}) ->
    [unsubscribe(S) || S <- Subs],
    ok.

%% Internal

topics() ->
    [<<"hecate.node.connected">>, <<"hecate.node.disconnected">>].

subscribe_to_topic(Topic) ->
    Callback = fun(Data) -> handle_fact(Topic, Data) end,
    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, Ref} ->
            logger:info("[mesh_connection_listener] Subscribed to ~s", [Topic]),
            Ref;
        {error, Reason} ->
            logger:warning("[mesh_connection_listener] Failed to subscribe to ~s: ~p",
                          [Topic, Reason]),
            undefined
    end.

unsubscribe(undefined) -> ok;
unsubscribe(Ref) -> hecate_mesh_client:unsubscribe(Ref).

handle_fact(Topic, Data) ->
    project(Topic, Data).

project(<<"hecate.node.connected">>, Data) ->
    project_connected(Data);
project(<<"hecate.node.disconnected">>, Data) ->
    project_disconnected(Data).

project_connected(Data) ->
    try
        #{
            <<"source_node">> := SourceNode,
            <<"target_node">> := TargetNode,
            <<"connected_at">> := ConnectedAt
        } = Data,

        %% target_node is us (they connected to us)
        MyIdentity = TargetNode,
        Now = erlang:system_time(millisecond),

        Sql = "INSERT OR REPLACE INTO my_connections
                   (remote_node, my_identity, connected_at, discovered_at)
               VALUES (?, ?, ?, ?)",

        query_node_lifecycle_store:execute(Sql, [SourceNode, MyIdentity, ConnectedAt, Now])
    catch
        Class:Reason:Stack ->
            logger:error("[mesh_connection_listener] Connected projection failed: ~p:~p~n~p",
                        [Class, Reason, Stack]),
            {error, projection_failed}
    end.

project_disconnected(Data) ->
    try
        #{
            <<"source_node">> := SourceNode,
            <<"target_node">> := TargetNode
        } = Data,

        MyIdentity = TargetNode,

        Sql = "DELETE FROM my_connections WHERE remote_node = ? AND my_identity = ?",
        query_node_lifecycle_store:execute(Sql, [SourceNode, MyIdentity])
    catch
        Class:Reason:Stack ->
            logger:error("[mesh_connection_listener] Disconnected projection failed: ~p:~p~n~p",
                        [Class, Reason, Stack]),
            {error, projection_failed}
    end.
