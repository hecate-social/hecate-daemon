%%% @doc Mentor subscription aggregate
%%% Maintains subscription state between agents and mentors.
-module(mentor_subscription_aggregate).
-behaviour(evoq_aggregate).

%% Behaviour callbacks
-export([init/1, execute/2, apply/2]).

%% Aliases for backward compatibility and testing
-export([initial_state/0, apply_event/2]).

%% Bit flag descriptions for status display
-export([flag_map/0]).

-define(SUBSCRIBED,   1).   %% 2^0
-define(UNSUBSCRIBED, 2).   %% 2^1

-record(subscription_state, {
    subscriber_id :: binary() | undefined,
    mentor_id     :: binary() | undefined,
    status        :: non_neg_integer(),
    subscribed_at :: non_neg_integer() | undefined
}).

-type state() :: #subscription_state{}.
-export_type([state/0]).

%% @doc Flag map for status display via evoq_bit_flags:to_string/2
-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> #{
    0              => <<"New">>,
    ?SUBSCRIBED    => <<"🔔 Subscribed"/utf8>>,
    ?UNSUBSCRIBED  => <<"🔕 Unsubscribed"/utf8>>
}.

%% @doc Behaviour callback: init/1
-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #subscription_state{
        subscriber_id = undefined,
        mentor_id = undefined,
        status = 0,
        subscribed_at = undefined
    }.

%% @doc Execute command against aggregate state
%% NOTE: evoq calls execute(State, Payload) - state first, then payload!
-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.
execute(State, #{command_type := <<"subscribe_to_mentor">>} = Payload) ->
    execute_subscribe(Payload, State);
execute(State, #{command_type := <<"unsubscribe_from_mentor">>} = Payload) ->
    execute_unsubscribe(Payload, State);
execute(State, Payload) ->
    execute(State, Payload#{command_type => <<"subscribe_to_mentor">>}).

execute_subscribe(Payload, #subscription_state{status = S}) ->
    case evoq_bit_flags:has(S, ?SUBSCRIBED) of
        false ->
            {ok, Cmd} = subscribe_to_mentor_v1:from_map(Payload),
            convert_events(maybe_subscribe_to_mentor:handle(Cmd), fun mentor_subscribed_v1:to_map/1);
        true ->
            case evoq_bit_flags:has(S, ?UNSUBSCRIBED) of
                false -> {error, already_subscribed};
                true ->
                    %% Re-subscribe after unsubscribe
                    {ok, Cmd} = subscribe_to_mentor_v1:from_map(Payload),
                    convert_events(maybe_subscribe_to_mentor:handle(Cmd), fun mentor_subscribed_v1:to_map/1)
            end
    end.

execute_unsubscribe(Payload, #subscription_state{status = S}) ->
    case evoq_bit_flags:has(S, ?SUBSCRIBED) of
        false -> {error, not_subscribed};
        true ->
            case evoq_bit_flags:has(S, ?UNSUBSCRIBED) of
                false ->
                    {ok, Cmd} = unsubscribe_from_mentor_v1:from_map(Payload),
                    convert_events(maybe_unsubscribe_from_mentor:handle(Cmd), fun mentor_unsubscribed_v1:to_map/1);
                true ->
                    {error, already_unsubscribed}
            end
    end.

convert_events({ok, Events}, ToMapFun) ->
    EventMaps = [ToMapFun(E) || E <- Events],
    {ok, EventMaps};
convert_events({error, Reason}, _ToMapFun) ->
    {error, Reason}.

%% @doc Behaviour callback: apply/2
%% NOTE: evoq calls apply(State, Event) - state first, then event!
-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

%% @doc Apply event to state (event sourcing)
%% Legacy function with (Event, State) order - use apply/2 instead
-spec apply_event(map(), state()) -> state().
apply_event(#{event_type := <<"mentor_subscribed_v1">>} = E, State) ->
    State#subscription_state{
        subscriber_id = maps:get(subscriber_id, E),
        mentor_id = maps:get(mentor_id, E),
        status = ?SUBSCRIBED,
        subscribed_at = maps:get(subscribed_at, E)
    };
apply_event(#{event_type := <<"mentor_unsubscribed_v1">>} = _E, State) ->
    State#subscription_state{
        status = evoq_bit_flags:set(State#subscription_state.status, ?UNSUBSCRIBED)
    };
apply_event(_E, State) ->
    State.
