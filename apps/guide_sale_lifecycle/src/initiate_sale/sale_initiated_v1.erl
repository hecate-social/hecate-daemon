%%% @doc sale_initiated_v1 event
%%% Emitted when a sale is initiated.
-module(sale_initiated_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_sale_id/1, get_seller_id/1, get_procurement_id/1,
         get_offering_id/1, get_plugin_id/1, get_initiated_at/1]).

-record(sale_initiated_v1, {
    sale_id        :: binary(),
    seller_id      :: binary(),
    procurement_id :: binary(),
    offering_id    :: binary(),
    plugin_id      :: binary(),
    initiated_at   :: integer()
}).

-export_type([sale_initiated_v1/0]).
-opaque sale_initiated_v1() :: #sale_initiated_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> sale_initiated_v1().
new(#{sale_id := SaleId, seller_id := SellerId, procurement_id := ProcurementId,
      offering_id := OfferingId, plugin_id := PluginId}) ->
    #sale_initiated_v1{
        sale_id        = SaleId,
        seller_id      = SellerId,
        procurement_id = ProcurementId,
        offering_id    = OfferingId,
        plugin_id      = PluginId,
        initiated_at   = erlang:system_time(millisecond)
    }.

-spec to_map(sale_initiated_v1()) -> map().
to_map(#sale_initiated_v1{} = E) ->
    #{
        event_type     => <<"sale_initiated_v1">>,
        sale_id        => E#sale_initiated_v1.sale_id,
        seller_id      => E#sale_initiated_v1.seller_id,
        procurement_id => E#sale_initiated_v1.procurement_id,
        offering_id    => E#sale_initiated_v1.offering_id,
        plugin_id      => E#sale_initiated_v1.plugin_id,
        initiated_at   => E#sale_initiated_v1.initiated_at
    }.

-spec from_map(map()) -> {ok, sale_initiated_v1()} | {error, term()}.
from_map(Map) ->
    SaleId        = hecate_api_utils:get_field(sale_id, Map),
    SellerId      = hecate_api_utils:get_field(seller_id, Map),
    ProcurementId = hecate_api_utils:get_field(procurement_id, Map),
    OfferingId    = hecate_api_utils:get_field(offering_id, Map),
    PluginId      = hecate_api_utils:get_field(plugin_id, Map),
    case {SaleId, SellerId, ProcurementId, OfferingId, PluginId} of
        {undefined, _, _, _, _} -> {error, invalid_event};
        {_, undefined, _, _, _} -> {error, invalid_event};
        {_, _, undefined, _, _} -> {error, invalid_event};
        {_, _, _, undefined, _} -> {error, invalid_event};
        {_, _, _, _, undefined} -> {error, invalid_event};
        _ ->
            {ok, #sale_initiated_v1{
                sale_id        = SaleId,
                seller_id      = SellerId,
                procurement_id = ProcurementId,
                offering_id    = OfferingId,
                plugin_id      = PluginId,
                initiated_at   = hecate_api_utils:get_field(initiated_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_sale_id(sale_initiated_v1()) -> binary().
get_sale_id(#sale_initiated_v1{sale_id = V}) -> V.

-spec get_seller_id(sale_initiated_v1()) -> binary().
get_seller_id(#sale_initiated_v1{seller_id = V}) -> V.

-spec get_procurement_id(sale_initiated_v1()) -> binary().
get_procurement_id(#sale_initiated_v1{procurement_id = V}) -> V.

-spec get_offering_id(sale_initiated_v1()) -> binary().
get_offering_id(#sale_initiated_v1{offering_id = V}) -> V.

-spec get_plugin_id(sale_initiated_v1()) -> binary().
get_plugin_id(#sale_initiated_v1{plugin_id = V}) -> V.

-spec get_initiated_at(sale_initiated_v1()) -> integer().
get_initiated_at(#sale_initiated_v1{initiated_at = V}) -> V.
