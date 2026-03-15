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

-export([state_module/0, init/1, execute/2, apply/2]).
-export([flag_map/0]).

-type state() :: #sale_state{}.
-export_type([state/0]).

-spec state_module() -> module().
state_module() -> sale_state.

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?SALE_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(AggregateId) ->
    {ok, sale_state:new(AggregateId)}.

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
%% Delegates to sale_state module (evoq_state behaviour).

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    sale_state:apply_event(State, Event).

%% --- Internal ---

get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
