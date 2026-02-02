%%% @doc Listener: Subscriber events (filtered)
%%%
%%% Subscribes to subscription.subscribed and subscription.unsubscribed mesh facts.
%%% Filters by MY_IDENTITIES - only processes facts where service owner is ME.
%%% Dispatches commands to create domain events.
-module(subscriber_events_listener).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    sub_subscribed :: reference() | undefined,
    sub_unsubscribed :: reference() | undefined
}).

%% API

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Callbacks

init([]) ->
    self() ! subscribe,
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(subscribe, State) ->
    SubSubscribed = subscribe_to_topic(<<"hecate.subscription.subscribed">>),
    SubUnsubscribed = subscribe_to_topic(<<"hecate.subscription.unsubscribed">>),
    {noreply, State#state{sub_subscribed = SubSubscribed, sub_unsubscribed = SubUnsubscribed}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{sub_subscribed = SubS, sub_unsubscribed = SubU}) ->
    unsubscribe(SubS),
    unsubscribe(SubU),
    ok.

%% Internal

subscribe_to_topic(Topic) ->
    Callback = fun(EventData) -> handle_fact(Topic, EventData) end,
    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, SubRef} ->
            logger:info("[subscriber_events_listener] Subscribed to ~s", [Topic]),
            SubRef;
        {error, Reason} ->
            logger:warning("[subscriber_events_listener] Failed to subscribe to ~s: ~p", [Topic, Reason]),
            undefined
    end.

unsubscribe(undefined) -> ok;
unsubscribe(SubRef) -> hecate_mesh_client:unsubscribe(SubRef).

handle_fact(<<"hecate.subscription.subscribed">>, EventData) ->
    handle_subscribed(EventData);
handle_fact(<<"hecate.subscription.unsubscribed">>, EventData) ->
    handle_unsubscribed(EventData).

handle_subscribed(EventData) ->
    #{
        <<"subscriber_identity">> := SubscriberIdentity,
        <<"owner_identity">> := OwnerIdentity,
        <<"topic">> := Topic,
        <<"subscribed_at">> := SubscribedAt
    } = EventData,

    Filter = maps:get(<<"filter">>, EventData, undefined),

    %% Only process if the owner is ME
    case is_my_identity(OwnerIdentity) of
        true ->
            Cmd = record_subscriber_v1:new(
                SubscriberIdentity, OwnerIdentity, Topic, Filter, SubscribedAt
            ),
            case maybe_record_subscriber:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:debug("[subscriber_events_listener] Recorded subscriber: ~s -> ~s/~s",
                                [SubscriberIdentity, OwnerIdentity, Topic]);
                {error, Reason} ->
                    logger:warning("[subscriber_events_listener] Failed to record subscriber: ~p", [Reason])
            end;
        false ->
            ok
    end.

handle_unsubscribed(EventData) ->
    #{
        <<"subscriber_identity">> := SubscriberIdentity,
        <<"owner_identity">> := OwnerIdentity,
        <<"topic">> := Topic,
        <<"unsubscribed_at">> := UnsubscribedAt
    } = EventData,

    case is_my_identity(OwnerIdentity) of
        true ->
            Cmd = record_unsubscriber_v1:new(
                SubscriberIdentity, OwnerIdentity, Topic, UnsubscribedAt
            ),
            case maybe_record_unsubscriber:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:debug("[subscriber_events_listener] Recorded unsubscriber: ~s -> ~s/~s",
                                [SubscriberIdentity, OwnerIdentity, Topic]);
                {error, Reason} ->
                    logger:warning("[subscriber_events_listener] Failed to record unsubscriber: ~p", [Reason])
            end;
        false ->
            ok
    end.

is_my_identity(Identity) ->
    ManagedIdentities = application:get_env(hecate, managed_identities, []),
    lists:member(Identity, ManagedIdentities).
