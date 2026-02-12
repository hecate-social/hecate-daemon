%%% @doc Mesh listener: Topic subscriptions.
%%%
%%% Subscribes to hecate.topic.subscribed and hecate.topic.unsubscribed
%%% mesh facts. Projects to my_subscribers table in the node lifecycle
%%% read model.
-module(mesh_subscription_listener).
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
    [<<"hecate.topic.subscribed">>, <<"hecate.topic.unsubscribed">>].

subscribe_to_topic(Topic) ->
    Callback = fun(Data) -> handle_fact(Topic, Data) end,
    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, Ref} ->
            logger:info("[mesh_subscription_listener] Subscribed to ~s", [Topic]),
            Ref;
        {error, Reason} ->
            logger:warning("[mesh_subscription_listener] Failed to subscribe to ~s: ~p",
                          [Topic, Reason]),
            undefined
    end.

unsubscribe(undefined) -> ok;
unsubscribe(Ref) -> hecate_mesh_client:unsubscribe(Ref).

handle_fact(Topic, Data) ->
    project(Topic, Data).

project(<<"hecate.topic.subscribed">>, Data) ->
    project_subscribed(Data);
project(<<"hecate.topic.unsubscribed">>, Data) ->
    project_unsubscribed(Data).

project_subscribed(Data) ->
    try
        #{
            <<"subscriber_identity">> := SubscriberIdentity,
            <<"my_identity">> := MyIdentity,
            <<"topic">> := Topic,
            <<"subscribed_at">> := SubscribedAt
        } = Data,

        Filter = maps:get(<<"filter">>, Data, null),
        Now = erlang:system_time(millisecond),

        Sql = "INSERT OR REPLACE INTO my_subscribers
                   (subscriber_identity, my_identity, topic, filter, subscribed_at, active, discovered_at)
               VALUES (?, ?, ?, ?, ?, 1, ?)",

        query_node_lifecycle_store:execute(Sql, [
            SubscriberIdentity, MyIdentity, Topic, Filter, SubscribedAt, Now
        ])
    catch
        Class:Reason:Stack ->
            logger:error("[mesh_subscription_listener] Subscribed projection failed: ~p:~p~n~p",
                        [Class, Reason, Stack]),
            {error, projection_failed}
    end.

project_unsubscribed(Data) ->
    try
        #{
            <<"subscriber_identity">> := SubscriberIdentity,
            <<"my_identity">> := MyIdentity,
            <<"topic">> := Topic
        } = Data,

        Sql = "UPDATE my_subscribers SET active = 0
               WHERE subscriber_identity = ? AND my_identity = ? AND topic = ?",

        query_node_lifecycle_store:execute(Sql, [SubscriberIdentity, MyIdentity, Topic])
    catch
        Class:Reason:Stack ->
            logger:error("[mesh_subscription_listener] Unsubscribed projection failed: ~p:~p~n~p",
                        [Class, Reason, Stack]),
            {error, projection_failed}
    end.
