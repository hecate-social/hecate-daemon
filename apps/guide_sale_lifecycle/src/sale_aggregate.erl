%%% @doc Sale aggregate.
%%%
%%% Stream: sale-{seller_id}-{plugin_id}
%%% Store: sales_store
%%%
%%% Lifecycle:
%%%   1. initiate_sale (birth event - sale_initiated_v1)
%%%   2. archive_sale (walking skeleton - sale_archived_v1)
%%% @end
-module(sale_aggregate).

-behaviour(evoq_aggregate).

-include("sale_status.hrl").
-include("sale_state.hrl").

-export([init/1, execute/2, apply/2]).
-export([initial_state/0, apply_event/2]).
-export([flag_map/0]).

-type state() :: #sale_state{}.
-export_type([state/0]).

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?SALE_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #sale_state{status = 0}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) - State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only initiate_sale allowed
execute(#sale_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"initiate_sale">> -> execute_initiate_sale(Payload);
        _ -> {error, sale_not_initiated}
    end;

%% Initiated — only archive_sale allowed
execute(#sale_state{status = S}, Payload) when S band ?SALE_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"archive_sale">> -> execute_archive_sale(Payload);
        _ -> {error, unknown_command}
    end;

%% Archived — nothing allowed
execute(#sale_state{status = S}, _Payload) when S band ?SALE_ARCHIVED =/= 0 ->
    {error, sale_archived};

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_initiate_sale(Payload) ->
    {ok, Cmd} = initiate_sale_v1:from_map(Payload),
    convert_events(maybe_initiate_sale:handle(Cmd), fun sale_initiated_v1:to_map/1).

execute_archive_sale(Payload) ->
    {ok, Cmd} = archive_sale_v1:from_map(Payload),
    convert_events(maybe_archive_sale:handle(Cmd), fun sale_archived_v1:to_map/1).

%% --- Apply ---
%% NOTE: evoq calls apply(State, Event) - State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

-spec apply_event(map(), state()) -> state().

apply_event(#{<<"event_type">> := <<"sale_initiated_v1">>} = E, S) -> apply_initiated(E, S);
apply_event(#{event_type := <<"sale_initiated_v1">>} = E, S)      -> apply_initiated(E, S);
apply_event(#{<<"event_type">> := <<"sale_archived_v1">>} = E, S)  -> apply_archived(E, S);
apply_event(#{event_type := <<"sale_archived_v1">>} = E, S)        -> apply_archived(E, S);
%% Unknown — ignore
apply_event(_E, S) -> S.

%% --- Apply helpers ---

apply_initiated(E, _State) ->
    #sale_state{
        sale_id        = get_value(sale_id, E),
        seller_id      = get_value(seller_id, E),
        procurement_id = get_value(procurement_id, E),
        offering_id    = get_value(offering_id, E),
        plugin_id      = get_value(plugin_id, E),
        status         = evoq_bit_flags:set(0, ?SALE_INITIATED),
        initiated_at   = get_value(initiated_at, E)
    }.

apply_archived(E, #sale_state{status = Status} = State) ->
    State#sale_state{
        status      = evoq_bit_flags:set(Status, ?SALE_ARCHIVED),
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
