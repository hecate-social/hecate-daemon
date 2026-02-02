%%% @doc Listener: Endorsement events (filtered)
%%%
%%% Subscribes to social.endorsed and social.endorsement_revoked mesh facts.
%%% Filters by MY_IDENTITIES - only processes facts where capability owner is ME.
%%% Dispatches commands to create domain events.
-module(endorsement_events_listener).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    sub_endorsed :: reference() | undefined,
    sub_revoked :: reference() | undefined
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
    SubEndorsed = subscribe_to_topic(<<"hecate.social.endorsed">>),
    SubRevoked = subscribe_to_topic(<<"hecate.social.endorsement_revoked">>),
    {noreply, State#state{sub_endorsed = SubEndorsed, sub_revoked = SubRevoked}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{sub_endorsed = SubE, sub_revoked = SubR}) ->
    unsubscribe(SubE),
    unsubscribe(SubR),
    ok.

%% Internal

subscribe_to_topic(Topic) ->
    Callback = fun(EventData) -> handle_fact(Topic, EventData) end,
    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, SubRef} ->
            logger:info("[endorsement_events_listener] Subscribed to ~s", [Topic]),
            SubRef;
        {error, Reason} ->
            logger:warning("[endorsement_events_listener] Failed to subscribe to ~s: ~p", [Topic, Reason]),
            undefined
    end.

unsubscribe(undefined) -> ok;
unsubscribe(SubRef) -> hecate_mesh_client:unsubscribe(SubRef).

handle_fact(<<"hecate.social.endorsed">>, EventData) ->
    handle_endorsed(EventData);
handle_fact(<<"hecate.social.endorsement_revoked">>, EventData) ->
    handle_endorsement_revoked(EventData).

handle_endorsed(EventData) ->
    #{
        <<"endorser_identity">> := EndorserIdentity,
        <<"capability_mri">> := CapabilityMri,
        <<"capability_owner">> := CapabilityOwner,
        <<"endorsed_at">> := EndorsedAt
    } = EventData,

    Comment = maps:get(<<"comment">>, EventData, undefined),

    %% Only process if the capability owner is ME
    case is_my_identity(CapabilityOwner) of
        true ->
            Cmd = record_endorsement_v1:new(
                EndorserIdentity, CapabilityMri, CapabilityOwner, Comment, EndorsedAt
            ),
            case maybe_record_endorsement:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:debug("[endorsement_events_listener] Recorded endorsement: ~s endorsed ~s",
                                [EndorserIdentity, CapabilityMri]);
                {error, Reason} ->
                    logger:warning("[endorsement_events_listener] Failed to record endorsement: ~p", [Reason])
            end;
        false ->
            ok
    end.

handle_endorsement_revoked(EventData) ->
    #{
        <<"endorser_identity">> := EndorserIdentity,
        <<"capability_mri">> := CapabilityMri,
        <<"capability_owner">> := CapabilityOwner,
        <<"revoked_at">> := RevokedAt
    } = EventData,

    case is_my_identity(CapabilityOwner) of
        true ->
            Cmd = record_endorsement_revoked_v1:new(
                EndorserIdentity, CapabilityMri, CapabilityOwner, RevokedAt
            ),
            case maybe_record_endorsement_revoked:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:debug("[endorsement_events_listener] Recorded endorsement revocation: ~s revoked ~s",
                                [EndorserIdentity, CapabilityMri]);
                {error, Reason} ->
                    logger:warning("[endorsement_events_listener] Failed to record endorsement revocation: ~p", [Reason])
            end;
        false ->
            ok
    end.

is_my_identity(Identity) ->
    ManagedIdentities = application:get_env(hecate, managed_identities, []),
    lists:member(Identity, ManagedIdentities).
