%%% @doc initiate_payment_v1 command
%%% Birth event for payment creation.
-module(initiate_payment_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_payment_id/1, get_consumer_id/1, get_procurement_id/1,
         get_offering_id/1, get_plugin_id/1, get_amount_cents/1,
         get_currency/1]).

-record(initiate_payment_v1, {
    payment_id     :: binary(),
    consumer_id    :: binary(),
    procurement_id :: binary(),
    offering_id    :: binary(),
    plugin_id      :: binary(),
    amount_cents   :: non_neg_integer() | undefined,
    currency       :: binary() | undefined
}).

-export_type([initiate_payment_v1/0]).
-opaque initiate_payment_v1() :: #initiate_payment_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, initiate_payment_v1()} | {error, term()}.
new(#{consumer_id := ConsumerId, procurement_id := ProcurementId,
      offering_id := OfferingId, plugin_id := PluginId} = Params) ->
    PaymentId = <<"payment-", ConsumerId/binary, "-", PluginId/binary>>,
    {ok, #initiate_payment_v1{
        payment_id = PaymentId,
        consumer_id = ConsumerId,
        procurement_id = ProcurementId,
        offering_id = OfferingId,
        plugin_id = PluginId,
        amount_cents = maps:get(amount_cents, Params, undefined),
        currency = maps:get(currency, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(initiate_payment_v1()) -> {ok, initiate_payment_v1()} | {error, term()}.
validate(#initiate_payment_v1{consumer_id = ConsumerId}) when
    not is_binary(ConsumerId); byte_size(ConsumerId) =:= 0 ->
    {error, invalid_consumer_id};
validate(#initiate_payment_v1{procurement_id = ProcurementId}) when
    not is_binary(ProcurementId); byte_size(ProcurementId) =:= 0 ->
    {error, invalid_procurement_id};
validate(#initiate_payment_v1{offering_id = OfferingId}) when
    not is_binary(OfferingId); byte_size(OfferingId) =:= 0 ->
    {error, invalid_offering_id};
validate(#initiate_payment_v1{plugin_id = PluginId}) when
    not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, invalid_plugin_id};
validate(#initiate_payment_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(initiate_payment_v1()) -> map().
to_map(#initiate_payment_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"initiate_payment">>,
        <<"payment_id">> => Cmd#initiate_payment_v1.payment_id,
        <<"consumer_id">> => Cmd#initiate_payment_v1.consumer_id,
        <<"procurement_id">> => Cmd#initiate_payment_v1.procurement_id,
        <<"offering_id">> => Cmd#initiate_payment_v1.offering_id,
        <<"plugin_id">> => Cmd#initiate_payment_v1.plugin_id,
        <<"amount_cents">> => Cmd#initiate_payment_v1.amount_cents,
        <<"currency">> => Cmd#initiate_payment_v1.currency
    }.

-spec from_map(map()) -> {ok, initiate_payment_v1()} | {error, term()}.
from_map(Map) ->
    ConsumerId = hecate_api_utils:get_field(consumer_id, Map),
    ProcurementId = hecate_api_utils:get_field(procurement_id, Map),
    OfferingId = hecate_api_utils:get_field(offering_id, Map),
    PluginId = hecate_api_utils:get_field(plugin_id, Map),
    case {ConsumerId, ProcurementId, OfferingId, PluginId} of
        {undefined, _, _, _} -> {error, missing_required_fields};
        {_, undefined, _, _} -> {error, missing_required_fields};
        {_, _, undefined, _} -> {error, missing_required_fields};
        {_, _, _, undefined} -> {error, missing_required_fields};
        _ ->
            PaymentId = <<"payment-", ConsumerId/binary, "-", PluginId/binary>>,
            {ok, #initiate_payment_v1{
                payment_id = PaymentId,
                consumer_id = ConsumerId,
                procurement_id = ProcurementId,
                offering_id = OfferingId,
                plugin_id = PluginId,
                amount_cents = hecate_api_utils:get_field(amount_cents, Map, undefined),
                currency = hecate_api_utils:get_field(currency, Map, undefined)
            }}
    end.

%% Accessors
-spec get_payment_id(initiate_payment_v1()) -> binary().
get_payment_id(#initiate_payment_v1{payment_id = V}) -> V.

-spec get_consumer_id(initiate_payment_v1()) -> binary().
get_consumer_id(#initiate_payment_v1{consumer_id = V}) -> V.

-spec get_procurement_id(initiate_payment_v1()) -> binary().
get_procurement_id(#initiate_payment_v1{procurement_id = V}) -> V.

-spec get_offering_id(initiate_payment_v1()) -> binary().
get_offering_id(#initiate_payment_v1{offering_id = V}) -> V.

-spec get_plugin_id(initiate_payment_v1()) -> binary().
get_plugin_id(#initiate_payment_v1{plugin_id = V}) -> V.

-spec get_amount_cents(initiate_payment_v1()) -> non_neg_integer() | undefined.
get_amount_cents(#initiate_payment_v1{amount_cents = V}) -> V.

-spec get_currency(initiate_payment_v1()) -> binary() | undefined.
get_currency(#initiate_payment_v1{currency = V}) -> V.
