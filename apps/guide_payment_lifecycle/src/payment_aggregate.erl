%%% @doc Payment aggregate.
%%%
%%% Stream: payment-{consumer_id}-{plugin_id}
%%% Store: payments_store
%%%
%%% Lifecycle:
%%%   1. initiate_payment (birth event - payment_initiated_v1)
%%%   2. archive_payment (payment_archived_v1)
%%% @end
-module(payment_aggregate).

-behaviour(evoq_aggregate).

-include("payment_status.hrl").
-include("payment_state.hrl").

-export([state_module/0, init/1, execute/2, apply/2]).
-export([flag_map/0]).

-type state() :: #payment_state{}.
-export_type([state/0]).

-spec state_module() -> module().
state_module() -> payment_state.

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?PAY_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(AggregateId) ->
    {ok, payment_state:new(AggregateId)}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) - State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only initiate_payment allowed
execute(#payment_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"initiate_payment">> -> execute_initiate_payment(Payload);
        _ -> {error, payment_not_initiated}
    end;

%% Initiated — only archive_payment allowed
execute(#payment_state{status = S}, Payload) when S band ?PAY_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"archive_payment">> -> execute_archive_payment(Payload);
        _ -> {error, unknown_command}
    end;

%% Archived — nothing allowed
execute(#payment_state{status = S}, _Payload) when S band ?PAY_ARCHIVED =/= 0 ->
    {error, payment_archived};

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_initiate_payment(Payload) ->
    {ok, Cmd} = initiate_payment_v1:from_map(Payload),
    convert_events(maybe_initiate_payment:handle(Cmd), fun payment_initiated_v1:to_map/1).

execute_archive_payment(Payload) ->
    {ok, Cmd} = archive_payment_v1:from_map(Payload),
    convert_events(maybe_archive_payment:handle(Cmd), fun payment_archived_v1:to_map/1).

%% --- Apply ---
%% Delegates to payment_state module (evoq_state behaviour).

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    payment_state:apply_event(State, Event).

%% --- Internal ---

get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
