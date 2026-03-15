%%% @doc State module for settings aggregate.
%%%
%%% Owns the state record, event folding, and serialization.
%%% @end
-module(settings_state).

-behaviour(evoq_state).

-include("settings_state.hrl").
-include("settings_status.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #settings_state{}.
-export_type([state/0]).

%% @doc Create initial empty state.
-spec new(binary()) -> state().
new(_AggregateId) ->
    #settings_state{
        linux_user = undefined,
        hostname = undefined,
        preferences = #{},
        status = 0,
        initiated_at = undefined
    }.

%% @doc Apply event to state. State FIRST, Event SECOND.
-spec apply_event(state(), map()) -> state().
apply_event(State, #{event_type := EventType} = Event) ->
    do_apply(EventType, State, Event);
apply_event(State, _) ->
    State.

%% @doc Serialize state to map.
-spec to_map(state()) -> map().
to_map(#settings_state{} = S) ->
    #{
        linux_user   => S#settings_state.linux_user,
        hostname     => S#settings_state.hostname,
        preferences  => S#settings_state.preferences,
        status       => S#settings_state.status,
        initiated_at => S#settings_state.initiated_at
    }.

%% ===================================================================
%% Event application
%% ===================================================================

do_apply(<<"settings_initiated_v1">>, State, Event) ->
    State#settings_state{
        linux_user = get_field(<<"linux_user">>, linux_user, Event),
        hostname = get_field(<<"hostname">>, hostname, Event),
        initiated_at = get_field(<<"initiated_at">>, initiated_at, Event),
        status = State#settings_state.status bor ?SETTINGS_INITIATED
    };

do_apply(<<"preferences_updated_v1">>, State, Event) ->
    NewPrefs = get_field(<<"preferences">>, preferences, Event),
    Merged = case is_map(NewPrefs) of
        true -> maps:merge(State#settings_state.preferences, NewPrefs);
        false -> State#settings_state.preferences
    end,
    State#settings_state{preferences = Merged};

%% Ignore old pairing events from existing event stores (backward read compat)
do_apply(<<"node_paired_v1">>, State, _Event) ->
    State;
do_apply(<<"node_unpaired_v1">>, State, _Event) ->
    State;

do_apply(_UnknownType, State, _Event) ->
    State.

%% ===================================================================
%% Internal
%% ===================================================================

get_field(BinKey, AtomKey, Event) ->
    maps:get(BinKey, Event, maps:get(AtomKey, Event, undefined)).
