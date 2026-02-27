%%% @doc Aggregate for realm membership lifecycle.
%%%
%%% Each realm membership is an independent aggregate.
%%% Stream: realmmembership-{uuid}.
%%% Lifecycle: initiate -> confirm -> revoke.
-module(membership_aggregate).
-behaviour(evoq_aggregate).

-include("membership_status.hrl").

%% Behaviour callbacks
-export([init/1, execute/2, apply/2]).

%% Internal / testing
-export([initial_state/0, apply_event/2, stream_id/1]).

-record(membership_state, {
    membership_id  :: binary() | undefined,
    realm_id       :: binary() | undefined,
    realm_url      :: binary() | undefined,
    oauth_account  :: binary() | undefined,
    oauth_provider :: binary() | undefined,
    initiated_at   :: integer() | undefined,
    confirmed_at   :: integer() | undefined,
    revoked_at     :: integer() | undefined,
    status         :: non_neg_integer()
}).

%% ===================================================================
%% Evoq callbacks
%% ===================================================================

init(_AggregateId) ->
    {ok, initial_state()}.

initial_state() ->
    #membership_state{
        membership_id = undefined,
        realm_id = undefined,
        realm_url = undefined,
        oauth_account = undefined,
        oauth_provider = undefined,
        initiated_at = undefined,
        confirmed_at = undefined,
        revoked_at = undefined,
        status = 0
    }.

-spec stream_id(binary()) -> binary().
stream_id(MembershipId) ->
    <<"realmmembership-", MembershipId/binary>>.

%% @doc Execute command — State FIRST (evoq convention).
execute(State, #{command_type := CmdType} = Payload) ->
    do_execute(CmdType, State, Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

%% @doc Apply event — State FIRST (evoq convention).
apply(State, Event) ->
    apply_event(State, Event).

apply_event(State, #{<<"event_type">> := EventType} = Event) ->
    do_apply(EventType, State, Event);
apply_event(State, #{event_type := EventType} = Event) ->
    do_apply(EventType, State, Event);
apply_event(State, _) ->
    State.

%% ===================================================================
%% Command routing
%% ===================================================================

do_execute(initiate_realm_membership, State, Payload) ->
    case State#membership_state.status band ?MEMBERSHIP_INITIATED of
        0 -> maybe_initiate_realm_membership:handle_from_map(Payload);
        _ -> {error, already_initiated}
    end;

do_execute(confirm_realm_membership, State, Payload) ->
    case State#membership_state.status band ?MEMBERSHIP_INITIATED of
        0 -> {error, not_initiated};
        _ ->
            case State#membership_state.status band ?MEMBERSHIP_CONFIRMED of
                0 -> maybe_confirm_realm_membership:handle_from_map(Payload);
                _ -> {error, already_confirmed}
            end
    end;

do_execute(revoke_realm_membership, State, Payload) ->
    case State#membership_state.status band ?MEMBERSHIP_CONFIRMED of
        0 -> {error, not_confirmed};
        _ ->
            case State#membership_state.status band ?MEMBERSHIP_REVOKED of
                0 -> maybe_revoke_realm_membership:handle_from_map(Payload);
                _ -> {error, already_revoked}
            end
    end;

do_execute(_Unknown, _State, _Payload) ->
    {error, unknown_command}.

%% ===================================================================
%% Event application
%% ===================================================================

do_apply(<<"realm_membership_initiated_v1">>, State, Event) ->
    State#membership_state{
        membership_id = get_field(<<"membership_id">>, membership_id, Event),
        realm_url = get_field(<<"realm_url">>, realm_url, Event),
        initiated_at = get_field(<<"initiated_at">>, initiated_at, Event),
        status = State#membership_state.status bor ?MEMBERSHIP_INITIATED
    };

do_apply(<<"realm_membership_confirmed_v1">>, State, Event) ->
    State#membership_state{
        realm_id = get_field(<<"realm_id">>, realm_id, Event),
        oauth_account = get_field(<<"oauth_account">>, oauth_account, Event),
        oauth_provider = get_field(<<"oauth_provider">>, oauth_provider, Event),
        confirmed_at = get_field(<<"confirmed_at">>, confirmed_at, Event),
        status = State#membership_state.status bor ?MEMBERSHIP_CONFIRMED
    };

do_apply(<<"realm_membership_revoked_v1">>, State, Event) ->
    State#membership_state{
        revoked_at = get_field(<<"revoked_at">>, revoked_at, Event),
        status = State#membership_state.status bor ?MEMBERSHIP_REVOKED
    };

do_apply(_UnknownType, State, _Event) ->
    State.

%% ===================================================================
%% Internal
%% ===================================================================

get_field(BinKey, AtomKey, Event) ->
    maps:get(BinKey, Event, maps:get(AtomKey, Event, undefined)).
