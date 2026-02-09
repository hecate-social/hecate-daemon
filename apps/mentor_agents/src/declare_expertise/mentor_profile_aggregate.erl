%%% @doc Mentor profile aggregate
%%% Maintains mentor profile state (expertise declarations).
-module(mentor_profile_aggregate).
-behaviour(evoq_aggregate).

%% Behaviour callbacks
-export([init/1, execute/2, apply/2]).

%% Aliases for backward compatibility and testing
-export([initial_state/0, apply_event/2]).

%% Bit flag descriptions for status display
-export([flag_map/0]).

-define(ACTIVE,    1).   %% 2^0
-define(WITHDRAWN, 2).   %% 2^1

-record(mentor_profile_state, {
    agent_id    :: binary() | undefined,
    domains     :: [binary()],
    status      :: non_neg_integer(),
    declared_at :: non_neg_integer() | undefined
}).

-type state() :: #mentor_profile_state{}.
-export_type([state/0]).

%% @doc Flag map for status display via evoq_bit_flags:to_string/2
-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> #{
    0          => <<"New">>,
    ?ACTIVE    => <<"🟢 Active">>,
    ?WITHDRAWN => <<"🚫 Withdrawn">>
}.

%% @doc Behaviour callback: init/1
-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #mentor_profile_state{
        agent_id = undefined,
        domains = [],
        status = 0,
        declared_at = undefined
    }.

%% @doc Execute command against aggregate state
%% NOTE: evoq calls execute(State, Payload) - state first, then payload!
-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.
execute(State, #{command_type := <<"declare_expertise">>} = Payload) ->
    execute_declare_expertise(Payload, State);
execute(State, #{command_type := <<"withdraw_expertise">>} = Payload) ->
    execute_withdraw_expertise(Payload, State);
execute(State, Payload) ->
    execute(State, Payload#{command_type => <<"declare_expertise">>}).

execute_declare_expertise(Payload, _State) ->
    {ok, Cmd} = declare_expertise_v1:from_map(Payload),
    convert_events(maybe_declare_expertise:handle(Cmd), fun expertise_declared_v1:to_map/1).

execute_withdraw_expertise(Payload, #mentor_profile_state{agent_id = undefined}) ->
    %% Absorb payload to avoid unused warning
    _ = Payload,
    {error, profile_not_found};
execute_withdraw_expertise(Payload, #mentor_profile_state{status = Status}) ->
    case evoq_bit_flags:has(Status, ?WITHDRAWN) of
        false ->
            {ok, Cmd} = withdraw_expertise_v1:from_map(Payload),
            convert_events(maybe_withdraw_expertise:handle(Cmd), fun expertise_withdrawn_v1:to_map/1);
        true ->
            {error, already_withdrawn}
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
apply_event(#{event_type := <<"expertise_declared_v1">>} = E, State) ->
    State#mentor_profile_state{
        agent_id = maps:get(agent_id, E),
        domains = maps:get(domains, E, []),
        status = ?ACTIVE,
        declared_at = maps:get(declared_at, E)
    };
apply_event(#{event_type := <<"expertise_withdrawn_v1">>} = _E, State) ->
    State#mentor_profile_state{
        status = evoq_bit_flags:set(State#mentor_profile_state.status, ?WITHDRAWN)
    };
apply_event(_E, State) ->
    State.
