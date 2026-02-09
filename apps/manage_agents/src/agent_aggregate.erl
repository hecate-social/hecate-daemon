%%% @doc Agent aggregate
%%% Maintains Agent state and applies events.
%%% An Agent represents an AI specialist or generalist that can work on tasks.
-module(agent_aggregate).
-behaviour(evoq_aggregate).

%% Behaviour callbacks
-export([init/1, execute/2, apply/2]).

%% Aliases for backward compatibility and testing
-export([initial_state/0, apply_event/2]).

%% Bit flag descriptions for status display
-export([flag_map/0]).

%% Bit flags for agent status
-define(ACTIVATED, 1).   %% 2^0 - Agent has been activated
-define(IDLE,      2).   %% 2^1 - Agent is idle (waiting for tasks)
-define(WORKING,   4).   %% 2^2 - Agent is working on a task
-define(RETIRED,   8).   %% 2^3 - Agent has been retired

-record(agent_state, {
    agent_id        :: binary() | undefined,
    torch_id        :: binary() | undefined,
    agent_type      :: specialist | generalist | undefined,
    role            :: dna | anp | tni | dno | undefined,
    status          :: non_neg_integer(),
    current_task_id :: binary() | undefined,
    activated_at    :: non_neg_integer() | undefined
}).

-type state() :: #agent_state{}.
-export_type([state/0]).

%% @doc Flag map for status display via evoq_bit_flags:to_string/2
-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> #{
    0          => <<"New">>,
    ?ACTIVATED => <<"⚡ Activated"/utf8>>,
    ?IDLE      => <<"💤 Idle"/utf8>>,
    ?WORKING   => <<"🔧 Working"/utf8>>,
    ?RETIRED   => <<"🪦 Retired"/utf8>>
}.

%% @doc Behaviour callback: init/1
-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #agent_state{
        agent_id = undefined,
        torch_id = undefined,
        agent_type = undefined,
        role = undefined,
        status = 0,
        current_task_id = undefined,
        activated_at = undefined
    }.

%% @doc Execute command against aggregate state
%% NOTE: evoq calls execute(State, Payload) - state first, then payload!
-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.
execute(State, #{command_type := <<"activate_specialist">>} = Payload) ->
    execute_activate_specialist(Payload, State);
execute(_State, _Payload) ->
    {error, unknown_command}.

execute_activate_specialist(Payload, #agent_state{status = 0}) ->
    {ok, Cmd} = activate_specialist_v1:from_map(Payload),
    convert_events(maybe_activate_specialist:handle(Cmd), fun specialist_activated_v1:to_map/1);
execute_activate_specialist(_Payload, _State) ->
    {error, agent_already_activated}.

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
apply_event(#{<<"event_type">> := <<"specialist_activated_v1">>} = E, State) ->
    apply_specialist_activated(E, State);
apply_event(#{event_type := <<"specialist_activated_v1">>} = E, State) ->
    apply_specialist_activated(E, State);
apply_event(_E, State) ->
    State.

apply_specialist_activated(E, State) ->
    State#agent_state{
        agent_id = get_value(agent_id, E),
        torch_id = get_value(torch_id, E),
        agent_type = specialist,
        role = binary_to_role(get_value(role, E)),
        status = ?ACTIVATED bor ?IDLE,
        activated_at = get_value(activated_at, E)
    }.

%% Helper to convert binary role to atom
binary_to_role(<<"dna">>) -> dna;
binary_to_role(<<"anp">>) -> anp;
binary_to_role(<<"tni">>) -> tni;
binary_to_role(<<"dno">>) -> dno;
binary_to_role(Role) when is_atom(Role) -> Role;
binary_to_role(_) -> undefined.

%% Helper to get value from map with atom or binary keys
get_value(Key, Map) ->
    get_value(Key, Map, undefined).

get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> Default
            end
    end.
