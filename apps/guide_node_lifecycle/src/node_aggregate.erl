%%% @doc Unified aggregate for node lifecycle.
%%%
%%% A node is ONE entity per daemon. Identity, capabilities, mesh connections,
%%% subscriptions, UCANs, and connectors are all attributes of the node.
%%% Stream: node-{mri}.
-module(node_aggregate).

-include("node_lifecycle_status.hrl").

-export([initial_state/0, execute/2, apply_event/2]).

-record(node_state, {
    %% Identity (singleton)
    mri :: binary() | undefined,
    public_key :: binary() | undefined,
    key_type :: binary() | undefined,
    identity_metadata :: map(),
    registered :: boolean(),
    registered_at :: integer() | undefined,
    %% Capabilities (keyed by MRI)
    capabilities :: #{binary() => map()},
    %% Mesh connections (outbound: who I connect to)
    connections :: #{binary() => map()},
    endorsements_given :: #{binary() => map()},
    %% Subscriptions
    subscriptions :: #{binary() => map()},
    %% UCAN grants
    ucan_grants :: #{binary() => map()},
    %% Connectors
    connectors :: #{binary() => map()},
    %% Status (bit flags)
    status :: non_neg_integer()
}).

%% ===================================================================
%% Evoq callbacks
%% ===================================================================

initial_state() ->
    #node_state{
        mri = undefined,
        public_key = undefined,
        key_type = undefined,
        identity_metadata = #{},
        registered = false,
        registered_at = undefined,
        capabilities = #{},
        connections = #{},
        endorsements_given = #{},
        subscriptions = #{},
        ucan_grants = #{},
        connectors = #{},
        status = 0
    }.

%% @doc Execute command — routes to the correct handler.
%% State comes FIRST (evoq convention).
execute(State, #{command_type := CmdType} = Payload) ->
    do_execute(CmdType, State, Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

%% @doc Apply event to state.
apply_event(State, #{<<"event_type">> := EventType} = Event) ->
    do_apply(EventType, State, Event);
apply_event(State, #{event_type := EventType} = Event) ->
    do_apply(EventType, State, Event);
apply_event(State, _) ->
    State.

%% ===================================================================
%% Command routing
%% ===================================================================

%% Identity
do_execute(register_identity, State, Payload) ->
    case State#node_state.registered of
        true -> {error, already_registered};
        false -> maybe_register_identity:handle_from_map(Payload)
    end;
do_execute(update_identity, State, Payload) ->
    case State#node_state.registered of
        true -> maybe_update_identity:handle_from_map(Payload);
        false -> {error, not_registered}
    end;

%% Capabilities
do_execute(announce_capability, _State, Payload) ->
    maybe_announce_capability:handle_from_map(Payload);
do_execute(update_capability, _State, Payload) ->
    maybe_update_capability:handle_from_map(Payload);
do_execute(retract_capability, _State, Payload) ->
    maybe_retract_capability:handle_from_map(Payload);

%% Mesh connections
do_execute(connect_node, _State, Payload) ->
    maybe_connect_node:handle_from_map(Payload);
do_execute(disconnect_node, _State, Payload) ->
    maybe_disconnect_node:handle_from_map(Payload);
do_execute(endorse_capability, _State, Payload) ->
    maybe_endorse_capability:handle_from_map(Payload);
do_execute(revoke_endorsement, _State, Payload) ->
    maybe_revoke_endorsement:handle_from_map(Payload);

%% Subscriptions
do_execute(subscribe_topic, _State, Payload) ->
    maybe_subscribe_topic:handle_from_map(Payload);
do_execute(unsubscribe_topic, _State, Payload) ->
    maybe_unsubscribe_topic:handle_from_map(Payload);

%% UCAN
do_execute(grant_ucan, _State, Payload) ->
    maybe_grant_ucan:handle_from_map(Payload);
do_execute(revoke_ucan, _State, Payload) ->
    maybe_revoke_ucan:handle_from_map(Payload);

%% Connectors
do_execute(register_connector, _State, Payload) ->
    maybe_register_connector:handle_from_map(Payload);
do_execute(revoke_connector, _State, Payload) ->
    maybe_revoke_connector:handle_from_map(Payload);
do_execute(activate_connector, _State, Payload) ->
    maybe_activate_connector:handle_from_map(Payload);
do_execute(suspend_connector, _State, Payload) ->
    maybe_suspend_connector:handle_from_map(Payload);

do_execute(_Unknown, _State, _Payload) ->
    {error, unknown_command}.

%% ===================================================================
%% Event application
%% ===================================================================

%% Identity
do_apply(<<"identity_registered_v1">>, State, Event) ->
    State#node_state{
        mri = maps:get(<<"mri">>, Event, maps:get(mri, Event, undefined)),
        public_key = maps:get(<<"public_key">>, Event, maps:get(public_key, Event, undefined)),
        key_type = maps:get(<<"key_type">>, Event, maps:get(key_type, Event, undefined)),
        identity_metadata = maps:get(<<"metadata">>, Event, maps:get(metadata, Event, #{})),
        registered = true,
        registered_at = maps:get(<<"registered_at">>, Event, maps:get(registered_at, Event, undefined)),
        status = State#node_state.status bor ?NL_REGISTERED
    };
do_apply(<<"identity_updated_v1">>, State, Event) ->
    NewMeta = maps:get(<<"metadata">>, Event, maps:get(metadata, Event, #{})),
    State#node_state{
        identity_metadata = maps:merge(State#node_state.identity_metadata, NewMeta)
    };

%% Capabilities
do_apply(<<"capability_announced_v1">>, State, Event) ->
    MRI = maps:get(<<"capability_mri">>, Event, maps:get(capability_mri, Event, <<>>)),
    State#node_state{
        capabilities = maps:put(MRI, Event, State#node_state.capabilities)
    };
do_apply(<<"capability_updated_v1">>, State, Event) ->
    MRI = maps:get(<<"capability_mri">>, Event, maps:get(capability_mri, Event, <<>>)),
    case maps:find(MRI, State#node_state.capabilities) of
        {ok, Existing} ->
            State#node_state{
                capabilities = maps:put(MRI, maps:merge(Existing, Event), State#node_state.capabilities)
            };
        error ->
            State
    end;
do_apply(<<"capability_retracted_v1">>, State, Event) ->
    MRI = maps:get(<<"capability_mri">>, Event, maps:get(capability_mri, Event, <<>>)),
    State#node_state{
        capabilities = maps:remove(MRI, State#node_state.capabilities)
    };

%% Mesh connections (renamed from follow/unfollow)
do_apply(<<"node_connected_v1">>, State, Event) ->
    Target = maps:get(<<"target_node">>, Event, maps:get(target_node, Event, <<>>)),
    State#node_state{
        connections = maps:put(Target, Event, State#node_state.connections)
    };
do_apply(<<"node_disconnected_v1">>, State, Event) ->
    Target = maps:get(<<"target_node">>, Event, maps:get(target_node, Event, <<>>)),
    State#node_state{
        connections = maps:remove(Target, State#node_state.connections)
    };
do_apply(<<"capability_endorsed_v1">>, State, Event) ->
    MRI = maps:get(<<"capability_mri">>, Event, maps:get(capability_mri, Event, <<>>)),
    Endorser = maps:get(<<"endorser_identity">>, Event, maps:get(endorser_identity, Event, <<>>)),
    Key = <<Endorser/binary, ":", MRI/binary>>,
    State#node_state{
        endorsements_given = maps:put(Key, Event, State#node_state.endorsements_given)
    };
do_apply(<<"endorsement_revoked_v1">>, State, Event) ->
    MRI = maps:get(<<"capability_mri">>, Event, maps:get(capability_mri, Event, <<>>)),
    Endorser = maps:get(<<"endorser_identity">>, Event, maps:get(endorser_identity, Event, <<>>)),
    Key = <<Endorser/binary, ":", MRI/binary>>,
    State#node_state{
        endorsements_given = maps:remove(Key, State#node_state.endorsements_given)
    };

%% Subscriptions (renamed from subscribed/unsubscribed)
do_apply(<<"topic_subscribed_v1">>, State, Event) ->
    Topic = maps:get(<<"topic">>, Event, maps:get(topic, Event, <<>>)),
    State#node_state{
        subscriptions = maps:put(Topic, Event, State#node_state.subscriptions)
    };
do_apply(<<"topic_unsubscribed_v1">>, State, Event) ->
    Topic = maps:get(<<"topic">>, Event, maps:get(topic, Event, <<>>)),
    State#node_state{
        subscriptions = maps:remove(Topic, State#node_state.subscriptions)
    };

%% UCAN (renamed from capability_granted/revoked)
do_apply(<<"ucan_granted_v1">>, State, Event) ->
    CapId = maps:get(<<"capability_id">>, Event, maps:get(capability_id, Event, <<>>)),
    State#node_state{
        ucan_grants = maps:put(CapId, Event, State#node_state.ucan_grants)
    };
do_apply(<<"ucan_revoked_v1">>, State, Event) ->
    CapId = maps:get(<<"capability_id">>, Event, maps:get(capability_id, Event, <<>>)),
    State#node_state{
        ucan_grants = maps:remove(CapId, State#node_state.ucan_grants)
    };

%% Connectors
do_apply(<<"connector_registered_v1">>, State, Event) ->
    ConnId = maps:get(<<"connector_id">>, Event, maps:get(connector_id, Event, <<>>)),
    ConnState = #{status => ?CONN_REGISTERED bor ?CONN_ACTIVE, event => Event},
    State#node_state{
        connectors = maps:put(ConnId, ConnState, State#node_state.connectors)
    };
do_apply(<<"connector_revoked_v1">>, State, Event) ->
    ConnId = maps:get(<<"connector_id">>, Event, maps:get(connector_id, Event, <<>>)),
    case maps:find(ConnId, State#node_state.connectors) of
        {ok, Conn} ->
            NewStatus = (maps:get(status, Conn, 0) band (bnot ?CONN_ACTIVE)) bor ?CONN_REVOKED,
            State#node_state{
                connectors = maps:put(ConnId, Conn#{status => NewStatus, revoked_event => Event}, State#node_state.connectors)
            };
        error -> State
    end;
do_apply(<<"connector_activated_v1">>, State, Event) ->
    ConnId = maps:get(<<"connector_id">>, Event, maps:get(connector_id, Event, <<>>)),
    case maps:find(ConnId, State#node_state.connectors) of
        {ok, Conn} ->
            NewStatus = (maps:get(status, Conn, 0) band (bnot ?CONN_SUSPENDED)) bor ?CONN_ACTIVE,
            State#node_state{
                connectors = maps:put(ConnId, Conn#{status => NewStatus}, State#node_state.connectors)
            };
        error -> State
    end;
do_apply(<<"connector_suspended_v1">>, State, Event) ->
    ConnId = maps:get(<<"connector_id">>, Event, maps:get(connector_id, Event, <<>>)),
    case maps:find(ConnId, State#node_state.connectors) of
        {ok, Conn} ->
            NewStatus = (maps:get(status, Conn, 0) band (bnot ?CONN_ACTIVE)) bor ?CONN_SUSPENDED,
            State#node_state{
                connectors = maps:put(ConnId, Conn#{status => NewStatus}, State#node_state.connectors)
            };
        error -> State
    end;

%% Unknown event — ignore
do_apply(_UnknownType, State, _Event) ->
    State.
