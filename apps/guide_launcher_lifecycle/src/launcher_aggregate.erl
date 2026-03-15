%%% @doc Launcher aggregate (singleton).
%%%
%%% Stream: launcher-launcher
%%% Store: launcher_store
%%%
%%% Lifecycle:
%%%   1. initialize_launcher (birth event - launcher_initialized_v1)
%%%   2. register_entry (add app to launcher)
%%%   3. unregister_entry (remove app from launcher)
%%%   4. reorganize_launcher (full layout update)
%%% @end
-module(launcher_aggregate).

-behaviour(evoq_aggregate).

-include("launcher_status.hrl").
-include("launcher_state.hrl").

-export([state_module/0, init/1, execute/2, apply/2]).
-export([flag_map/0]).

-type state() :: #launcher_state{}.
-export_type([state/0]).

-spec state_module() -> module().
state_module() -> launcher_state.

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?LNCH_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(AggregateId) ->
    {ok, launcher_state:new(AggregateId)}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) - State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only initialize_launcher allowed
execute(#launcher_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"initialize_launcher">> -> execute_initialize(Payload);
        _ -> {error, launcher_not_initialized}
    end;

%% Initialized — route commands
execute(#launcher_state{status = S} = State, Payload) when S band ?LNCH_INITIALIZED =/= 0 ->
    case get_command_type(Payload) of
        <<"initialize_launcher">> -> {error, launcher_already_initialized};
        <<"register_entry">> -> execute_register_entry(Payload, State);
        <<"unregister_entry">> -> execute_unregister_entry(Payload, State);
        <<"reorganize_launcher">> -> execute_reorganize(Payload, State);
        _ -> {error, unknown_command}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_initialize(Payload) ->
    {ok, Cmd} = initialize_launcher_v1:from_map(Payload),
    convert_events(maybe_initialize_launcher:handle(Cmd), fun launcher_initialized_v1:to_map/1).

execute_register_entry(Payload, State) ->
    {ok, Cmd} = register_entry_v1:from_map(Payload),
    convert_events(maybe_register_entry:handle(Cmd, State), fun entry_registered_v1:to_map/1).

execute_unregister_entry(Payload, State) ->
    {ok, Cmd} = unregister_entry_v1:from_map(Payload),
    convert_events(maybe_unregister_entry:handle(Cmd, State), fun entry_unregistered_v1:to_map/1).

execute_reorganize(Payload, State) ->
    {ok, Cmd} = reorganize_launcher_v1:from_map(Payload),
    convert_events(maybe_reorganize_launcher:handle(Cmd, State), fun launcher_reorganized_v1:to_map/1).

%% --- Apply ---
%% NOTE: evoq calls apply(State, Event) - State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    launcher_state:apply_event(State, Event).

%% --- Internal ---

get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
