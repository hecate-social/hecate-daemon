%%% @doc Listener: Follower events (filtered)
%%%
%%% Subscribes to social.followed and social.unfollowed mesh facts.
%%% Filters by MY_IDENTITIES - only processes facts where target is ME.
%%% Dispatches commands to create domain events.
-module(follower_events_listener).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    sub_followed :: reference() | undefined,
    sub_unfollowed :: reference() | undefined
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
    SubFollowed = subscribe_to_topic(<<"hecate.social.followed">>),
    SubUnfollowed = subscribe_to_topic(<<"hecate.social.unfollowed">>),
    {noreply, State#state{sub_followed = SubFollowed, sub_unfollowed = SubUnfollowed}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{sub_followed = SubF, sub_unfollowed = SubU}) ->
    unsubscribe(SubF),
    unsubscribe(SubU),
    ok.

%% Internal

subscribe_to_topic(Topic) ->
    Callback = fun(EventData) -> handle_fact(Topic, EventData) end,
    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, SubRef} ->
            logger:info("[follower_events_listener] Subscribed to ~s", [Topic]),
            SubRef;
        {error, Reason} ->
            logger:warning("[follower_events_listener] Failed to subscribe to ~s: ~p", [Topic, Reason]),
            undefined
    end.

unsubscribe(undefined) -> ok;
unsubscribe(SubRef) -> hecate_mesh_client:unsubscribe(SubRef).

handle_fact(<<"hecate.social.followed">>, EventData) ->
    handle_followed(EventData);
handle_fact(<<"hecate.social.unfollowed">>, EventData) ->
    handle_unfollowed(EventData).

handle_followed(EventData) ->
    #{
        <<"follower_identity">> := FollowerIdentity,
        <<"followed_identity">> := FollowedIdentity,
        <<"followed_at">> := FollowedAt
    } = EventData,

    %% Only process if the followed identity is ME
    case is_my_identity(FollowedIdentity) of
        true ->
            Cmd = record_follower_v1:new(FollowerIdentity, FollowedIdentity, FollowedAt),
            case maybe_record_follower:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:debug("[follower_events_listener] Recorded follower: ~s -> ~s",
                                [FollowerIdentity, FollowedIdentity]);
                {error, Reason} ->
                    logger:warning("[follower_events_listener] Failed to record follower: ~p", [Reason])
            end;
        false ->
            ok  %% Not about me - ignore
    end.

handle_unfollowed(EventData) ->
    #{
        <<"unfollower_identity">> := UnfollowerIdentity,
        <<"unfollowed_identity">> := UnfollowedIdentity,
        <<"unfollowed_at">> := UnfollowedAt
    } = EventData,

    case is_my_identity(UnfollowedIdentity) of
        true ->
            Cmd = record_unfollower_v1:new(UnfollowerIdentity, UnfollowedIdentity, UnfollowedAt),
            case maybe_record_unfollower:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:debug("[follower_events_listener] Recorded unfollower: ~s -> ~s",
                                [UnfollowerIdentity, UnfollowedIdentity]);
                {error, Reason} ->
                    logger:warning("[follower_events_listener] Failed to record unfollower: ~p", [Reason])
            end;
        false ->
            ok
    end.

is_my_identity(Identity) ->
    ManagedIdentities = application:get_env(hecate, managed_identities, []),
    lists:member(Identity, ManagedIdentities).
