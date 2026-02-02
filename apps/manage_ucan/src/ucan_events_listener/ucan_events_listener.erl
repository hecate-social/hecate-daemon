%%% @doc Listener: UCAN capability events (filtered)
%%%
%%% SECURITY-CRITICAL: Handles incoming capability grants and revocations.
%%% Subscribes to ucan.granted and ucan.revoked mesh facts.
%%% Filters by MY_IDENTITIES - only processes facts where audience is ME.
%%% Dispatches commands to record received capabilities.
-module(ucan_events_listener).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    sub_granted :: reference() | undefined,
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
    SubGranted = subscribe_to_topic(<<"hecate.ucan.granted">>),
    SubRevoked = subscribe_to_topic(<<"hecate.ucan.revoked">>),
    {noreply, State#state{sub_granted = SubGranted, sub_revoked = SubRevoked}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{sub_granted = SubG, sub_revoked = SubR}) ->
    unsubscribe(SubG),
    unsubscribe(SubR),
    ok.

%% Internal

subscribe_to_topic(Topic) ->
    Callback = fun(EventData) -> handle_fact(Topic, EventData) end,
    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, SubRef} ->
            logger:info("[ucan_events_listener] Subscribed to ~s", [Topic]),
            SubRef;
        {error, Reason} ->
            logger:warning("[ucan_events_listener] Failed to subscribe to ~s: ~p", [Topic, Reason]),
            undefined
    end.

unsubscribe(undefined) -> ok;
unsubscribe(SubRef) -> hecate_mesh_client:unsubscribe(SubRef).

handle_fact(<<"hecate.ucan.granted">>, EventData) ->
    handle_granted(EventData);
handle_fact(<<"hecate.ucan.revoked">>, EventData) ->
    handle_revoked(EventData).

%% SECURITY-CRITICAL: Only process capabilities granted TO one of my identities
handle_granted(EventData) ->
    #{
        <<"capability_id">> := CapabilityId,
        <<"issuer">> := Issuer,
        <<"audience">> := Audience,
        <<"resource">> := Resource,
        <<"actions">> := Actions,
        <<"expires_at">> := ExpiresAt,
        <<"granted_at">> := GrantedAt
    } = EventData,

    TokenCid = maps:get(<<"token_cid">>, EventData, undefined),

    %% Only process if the audience (recipient) is ME
    case is_my_identity(Audience) of
        true ->
            logger:info("[ucan_events_listener] SECURITY: Received capability grant ~s from ~s",
                       [CapabilityId, Issuer]),
            Cmd = receive_capability_v1:new(
                CapabilityId, Issuer, Audience, Resource, Actions,
                ExpiresAt, GrantedAt, TokenCid
            ),
            case maybe_receive_capability:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:debug("[ucan_events_listener] Recorded received capability: ~s",
                                [CapabilityId]);
                {error, Reason} ->
                    logger:warning("[ucan_events_listener] Failed to record capability: ~p", [Reason])
            end;
        false ->
            ok  %% Not for me - ignore
    end.

%% SECURITY-CRITICAL: Only process revocations of capabilities I hold
handle_revoked(EventData) ->
    #{
        <<"capability_id">> := CapabilityId,
        <<"revoker">> := Revoker,
        <<"audience">> := Audience,
        <<"revoked_at">> := RevokedAt
    } = EventData,

    case is_my_identity(Audience) of
        true ->
            logger:info("[ucan_events_listener] SECURITY: Capability ~s revoked by ~s",
                       [CapabilityId, Revoker]),
            Cmd = receive_capability_revocation_v1:new(
                CapabilityId, Audience, Revoker, RevokedAt
            ),
            case maybe_receive_capability_revocation:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:debug("[ucan_events_listener] Recorded capability revocation: ~s",
                                [CapabilityId]);
                {error, Reason} ->
                    logger:warning("[ucan_events_listener] Failed to record revocation: ~p", [Reason])
            end;
        false ->
            ok
    end.

is_my_identity(Identity) ->
    ManagedIdentities = application:get_env(hecate, managed_identities, []),
    lists:member(Identity, ManagedIdentities).
