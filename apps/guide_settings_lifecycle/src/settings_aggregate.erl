%%% @doc Aggregate for settings lifecycle.
%%%
%%% One singleton per daemon. Stream: settings-{linux_user}@{hostname}.
%%% Manages: identity, preferences.
%%% Realm memberships are handled by guide_realm_memberships.
-module(settings_aggregate).
-behaviour(evoq_aggregate).

-include("settings_status.hrl").

%% Behaviour callbacks
-export([init/1, execute/2, apply/2]).

%% Internal / testing
-export([initial_state/0, apply_event/2, stream_id/0]).

-record(settings_state, {
    linux_user     :: binary() | undefined,
    hostname       :: binary() | undefined,
    preferences    :: map(),
    status         :: non_neg_integer(),
    initiated_at   :: integer() | undefined
}).

%% ===================================================================
%% Evoq callbacks
%% ===================================================================

init(_AggregateId) ->
    {ok, initial_state()}.

initial_state() ->
    #settings_state{
        linux_user = undefined,
        hostname = undefined,
        preferences = #{},
        status = 0,
        initiated_at = undefined
    }.

-spec stream_id() -> binary().
stream_id() ->
    User = shared_host:user(),
    Host = shared_host:hostname(),
    <<"settings-", User/binary, "@", Host/binary>>.

%% @doc Execute command — State FIRST (evoq convention).
execute(State, #{command_type := CmdType} = Payload) ->
    do_execute(CmdType, State, Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

%% @doc Evoq callback: apply/2 — State FIRST.
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

do_execute(initiate_settings, State, Payload) ->
    case State#settings_state.status band ?SETTINGS_INITIATED of
        0 -> maybe_initiate_settings:handle_from_map(Payload);
        _ -> {error, already_initiated}
    end;

do_execute(update_preferences, State, Payload) ->
    case State#settings_state.status band ?SETTINGS_INITIATED of
        0 -> {error, not_initiated};
        _ -> maybe_update_preferences:handle_from_map(Payload)
    end;

do_execute(_Unknown, _State, _Payload) ->
    {error, unknown_command}.

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
