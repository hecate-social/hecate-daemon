%%% @doc Procurement aggregate.
%%%
%%% Stream: procurement-{consumer_id}-{plugin_id}
%%% Store: procurements_store
%%%
%%% Lifecycle:
%%%   1. initiate_procurement (birth event - procurement_initiated_v1)
%%%   2. archive_procurement (walking skeleton - procurement_archived_v1)
%%% @end
-module(procurement_aggregate).

-behaviour(evoq_aggregate).

-include("procurement_status.hrl").
-include("procurement_state.hrl").

-export([state_module/0, init/1, execute/2, apply/2]).
-export([flag_map/0]).

-type state() :: #procurement_state{}.
-export_type([state/0]).

-spec state_module() -> module().
state_module() -> procurement_state.

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?PROC_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(AggregateId) ->
    {ok, procurement_state:new(AggregateId)}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) - State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only initiate allowed
execute(#procurement_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"initiate_procurement">> -> execute_initiate_procurement(Payload);
        _ -> {error, procurement_not_initiated}
    end;

%% Archived — nothing allowed
execute(#procurement_state{status = S}, _Payload) when S band ?PROC_ARCHIVED =/= 0 ->
    {error, procurement_archived};

%% Initiated — only archive allowed
execute(#procurement_state{status = S}, Payload) when S band ?PROC_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"archive_procurement">> -> execute_archive_procurement(Payload);
        _ -> {error, unknown_command}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_initiate_procurement(Payload) ->
    {ok, Cmd} = initiate_procurement_v1:from_map(Payload),
    convert_events(maybe_initiate_procurement:handle(Cmd), fun procurement_initiated_v1:to_map/1).

execute_archive_procurement(Payload) ->
    {ok, Cmd} = archive_procurement_v1:from_map(Payload),
    convert_events(maybe_archive_procurement:handle(Cmd), fun procurement_archived_v1:to_map/1).

%% --- Apply ---
%% Delegates to procurement_state module (evoq_state behaviour).

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    procurement_state:apply_event(State, Event).

%% --- Internal ---

get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
