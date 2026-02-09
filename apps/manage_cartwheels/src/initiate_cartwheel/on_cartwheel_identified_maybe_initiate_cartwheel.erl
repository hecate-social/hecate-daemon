%%% @doc Policy/Process Manager: React to cartwheel_identified facts
%%%
%%% When a torch identifies a cartwheel (bounded context), this policy
%%% decides whether and how to initiate that cartwheel.
%%%
%%% Naming convention: on_{source_event}_{action}_{target}
%%% - Source: cartwheel_identified (from manage_torches)
%%% - Action: maybe_initiate (policy decision)
%%% - Target: cartwheel (in manage_cartwheels)
%%%
%%% Current policy: Always initiate a cartwheel with the same name.
%%% Future policies may:
%%% - Skip initiation based on cartwheel type
%%% - Create with different configurations
%%% - Wait for additional conditions
%%%
%%% @end
-module(on_cartwheel_identified_maybe_initiate_cartwheel).

-export([handle/1]).

%% @doc Handle a cartwheel_identified fact and potentially initiate the cartwheel
-spec handle(map()) -> ok | {error, term()}.
handle(FactData) ->
    TorchId = get_field(torch_id, FactData),
    CartwheelId = get_field(cartwheel_id, FactData),
    ContextName = get_field(context_name, FactData),
    Description = get_field(description, FactData),

    logger:info("[policy] Processing cartwheel ~s (~s) from torch ~s",
                [CartwheelId, ContextName, TorchId]),
    logger:info("[policy] Extracted fields - torch_id: ~p, cartwheel_id: ~p, context_name: ~p",
                [TorchId, CartwheelId, ContextName]),

    %% Policy: Always initiate (future: conditional)
    do_initiate(#{
        cartwheel_id => CartwheelId,
        torch_id => TorchId,
        context_name => ContextName,
        description => Description
    }).

%% @doc Create and dispatch the initiate_cartwheel command
-spec do_initiate(map()) -> ok | {error, term()}.
do_initiate(Params) ->
    Result = create_and_dispatch(Params),
    log_result(maps:get(cartwheel_id, Params), Result),
    Result.

create_and_dispatch(Params) ->
    with_command(initiate_cartwheel_v1:new(Params)).

with_command({ok, Cmd}) ->
    dispatch(maybe_initiate_cartwheel:dispatch(Cmd));
with_command({error, _} = Error) ->
    Error.

dispatch({ok, _Version, _Events}) -> ok;
dispatch({error, _} = Error) -> Error.

log_result(CartwheelId, ok) ->
    logger:info("[policy] Cartwheel ~s initiated", [CartwheelId]);
log_result(CartwheelId, {error, Reason}) ->
    logger:error("[policy] Failed to initiate cartwheel ~s: ~p", [CartwheelId, Reason]).

%% @private Get field from map supporting both atom and binary keys
get_field(Key, Map) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    maps:get(Key, Map, maps:get(BinKey, Map, undefined)).
