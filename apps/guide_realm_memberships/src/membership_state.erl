%%% @doc State module for realm membership aggregate.
%%%
%%% Owns the state record, event folding, and serialization.
%%% @end
-module(membership_state).

-behaviour(evoq_state).

-include("membership_state.hrl").
-include("membership_status.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #membership_state{}.
-export_type([state/0]).

%% @doc Create initial empty state.
-spec new(binary()) -> state().
new(_AggregateId) ->
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

%% @doc Apply event to state. State FIRST, Event SECOND.
-spec apply_event(state(), map()) -> state().
apply_event(State, #{event_type := EventType} = Event) ->
    do_apply(EventType, State, Event);
apply_event(State, _) ->
    State.

%% @doc Serialize state to map.
-spec to_map(state()) -> map().
to_map(#membership_state{} = S) ->
    #{
        membership_id  => S#membership_state.membership_id,
        realm_id       => S#membership_state.realm_id,
        realm_url      => S#membership_state.realm_url,
        oauth_account  => S#membership_state.oauth_account,
        oauth_provider => S#membership_state.oauth_provider,
        initiated_at   => S#membership_state.initiated_at,
        confirmed_at   => S#membership_state.confirmed_at,
        revoked_at     => S#membership_state.revoked_at,
        status         => S#membership_state.status
    }.

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
