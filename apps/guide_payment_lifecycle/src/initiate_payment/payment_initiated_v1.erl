%%% @doc payment_initiated_v1 event
%%% Emitted when a payment is initiated.
-module(payment_initiated_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_payment_id/1, get_consumer_id/1, get_procurement_id/1,
         get_offering_id/1, get_plugin_id/1, get_amount_cents/1,
         get_currency/1, get_initiated_at/1]).

-record(payment_initiated_v1, {
    payment_id     :: binary(),
    consumer_id    :: binary(),
    procurement_id :: binary(),
    offering_id    :: binary(),
    plugin_id      :: binary(),
    amount_cents   :: non_neg_integer() | undefined,
    currency       :: binary() | undefined,
    initiated_at   :: integer()
}).

-export_type([payment_initiated_v1/0]).
-opaque payment_initiated_v1() :: #payment_initiated_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> payment_initiated_v1().
new(#{payment_id := PaymentId, consumer_id := ConsumerId,
      procurement_id := ProcurementId, offering_id := OfferingId,
      plugin_id := PluginId} = Params) ->
    #payment_initiated_v1{
        payment_id = PaymentId,
        consumer_id = ConsumerId,
        procurement_id = ProcurementId,
        offering_id = OfferingId,
        plugin_id = PluginId,
        amount_cents = maps:get(amount_cents, Params, undefined),
        currency = maps:get(currency, Params, undefined),
        initiated_at = erlang:system_time(millisecond)
    }.

-spec to_map(payment_initiated_v1()) -> map().
to_map(#payment_initiated_v1{} = E) ->
    #{
        event_type => <<"payment_initiated_v1">>,
        payment_id => E#payment_initiated_v1.payment_id,
        consumer_id => E#payment_initiated_v1.consumer_id,
        procurement_id => E#payment_initiated_v1.procurement_id,
        offering_id => E#payment_initiated_v1.offering_id,
        plugin_id => E#payment_initiated_v1.plugin_id,
        amount_cents => E#payment_initiated_v1.amount_cents,
        currency => E#payment_initiated_v1.currency,
        initiated_at => E#payment_initiated_v1.initiated_at
    }.

-spec from_map(map()) -> {ok, payment_initiated_v1()} | {error, term()}.
from_map(Map) ->
    PaymentId = hecate_api_utils:get_field(payment_id, Map),
    ConsumerId = hecate_api_utils:get_field(consumer_id, Map),
    ProcurementId = hecate_api_utils:get_field(procurement_id, Map),
    OfferingId = hecate_api_utils:get_field(offering_id, Map),
    PluginId = hecate_api_utils:get_field(plugin_id, Map),
    case {PaymentId, ConsumerId, ProcurementId, OfferingId, PluginId} of
        {undefined, _, _, _, _} -> {error, invalid_event};
        {_, undefined, _, _, _} -> {error, invalid_event};
        {_, _, undefined, _, _} -> {error, invalid_event};
        {_, _, _, undefined, _} -> {error, invalid_event};
        {_, _, _, _, undefined} -> {error, invalid_event};
        _ ->
            {ok, #payment_initiated_v1{
                payment_id = PaymentId,
                consumer_id = ConsumerId,
                procurement_id = ProcurementId,
                offering_id = OfferingId,
                plugin_id = PluginId,
                amount_cents = hecate_api_utils:get_field(amount_cents, Map, undefined),
                currency = hecate_api_utils:get_field(currency, Map, undefined),
                initiated_at = hecate_api_utils:get_field(initiated_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_payment_id(payment_initiated_v1()) -> binary().
get_payment_id(#payment_initiated_v1{payment_id = V}) -> V.

-spec get_consumer_id(payment_initiated_v1()) -> binary().
get_consumer_id(#payment_initiated_v1{consumer_id = V}) -> V.

-spec get_procurement_id(payment_initiated_v1()) -> binary().
get_procurement_id(#payment_initiated_v1{procurement_id = V}) -> V.

-spec get_offering_id(payment_initiated_v1()) -> binary().
get_offering_id(#payment_initiated_v1{offering_id = V}) -> V.

-spec get_plugin_id(payment_initiated_v1()) -> binary().
get_plugin_id(#payment_initiated_v1{plugin_id = V}) -> V.

-spec get_amount_cents(payment_initiated_v1()) -> non_neg_integer() | undefined.
get_amount_cents(#payment_initiated_v1{amount_cents = V}) -> V.

-spec get_currency(payment_initiated_v1()) -> binary() | undefined.
get_currency(#payment_initiated_v1{currency = V}) -> V.

-spec get_initiated_at(payment_initiated_v1()) -> integer().
get_initiated_at(#payment_initiated_v1{initiated_at = V}) -> V.
