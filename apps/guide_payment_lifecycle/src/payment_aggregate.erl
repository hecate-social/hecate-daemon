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

-export([init/1, execute/2, apply/2]).
-export([initial_state/0, apply_event/2]).
-export([flag_map/0]).

-type state() :: #payment_state{}.
-export_type([state/0]).

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?PAY_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #payment_state{status = 0}.

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
%% NOTE: evoq calls apply(State, Event) - State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

-spec apply_event(map(), state()) -> state().

apply_event(#{<<"event_type">> := <<"payment_initiated_v1">>} = E, S) -> apply_initiated(E, S);
apply_event(#{event_type := <<"payment_initiated_v1">>} = E, S)      -> apply_initiated(E, S);
apply_event(#{<<"event_type">> := <<"payment_archived_v1">>} = E, S)  -> apply_archived(E, S);
apply_event(#{event_type := <<"payment_archived_v1">>} = E, S)       -> apply_archived(E, S);
%% Unknown — ignore
apply_event(_E, S) -> S.

%% --- Apply helpers ---

apply_initiated(E, _State) ->
    #payment_state{
        payment_id = get_value(payment_id, E),
        consumer_id = get_value(consumer_id, E),
        procurement_id = get_value(procurement_id, E),
        offering_id = get_value(offering_id, E),
        plugin_id = get_value(plugin_id, E),
        amount_cents = get_value(amount_cents, E),
        currency = get_value(currency, E),
        status = ?PAY_INITIATED,
        initiated_at = get_value(initiated_at, E)
    }.

apply_archived(E, #payment_state{status = Status} = State) ->
    State#payment_state{
        status = evoq_bit_flags:set(Status, ?PAY_ARCHIVED),
        archived_at = get_value(archived_at, E)
    }.

%% --- Internal ---

get_command_type(#{<<"command_type">> := T}) -> T;
get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
