%%% @doc initiate_sale_v1 command
%%% Birth event for sale creation.
-module(initiate_sale_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_sale_id/1, get_seller_id/1, get_procurement_id/1,
         get_offering_id/1, get_plugin_id/1]).

-record(initiate_sale_v1, {
    sale_id        :: binary(),
    seller_id      :: binary(),
    procurement_id :: binary(),
    offering_id    :: binary(),
    plugin_id      :: binary()
}).

-export_type([initiate_sale_v1/0]).
-opaque initiate_sale_v1() :: #initiate_sale_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, initiate_sale_v1()} | {error, term()}.
new(#{seller_id := SellerId, procurement_id := ProcurementId,
      offering_id := OfferingId, plugin_id := PluginId}) ->
    SaleId = <<"sale-", SellerId/binary, "-", PluginId/binary>>,
    {ok, #initiate_sale_v1{
        sale_id        = SaleId,
        seller_id      = SellerId,
        procurement_id = ProcurementId,
        offering_id    = OfferingId,
        plugin_id      = PluginId
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(initiate_sale_v1()) -> {ok, initiate_sale_v1()} | {error, term()}.
validate(#initiate_sale_v1{seller_id = SellerId}) when
    not is_binary(SellerId); byte_size(SellerId) =:= 0 ->
    {error, invalid_seller_id};
validate(#initiate_sale_v1{procurement_id = ProcurementId}) when
    not is_binary(ProcurementId); byte_size(ProcurementId) =:= 0 ->
    {error, invalid_procurement_id};
validate(#initiate_sale_v1{offering_id = OfferingId}) when
    not is_binary(OfferingId); byte_size(OfferingId) =:= 0 ->
    {error, invalid_offering_id};
validate(#initiate_sale_v1{plugin_id = PluginId}) when
    not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, invalid_plugin_id};
validate(#initiate_sale_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(initiate_sale_v1()) -> map().
to_map(#initiate_sale_v1{} = Cmd) ->
    #{
        <<"command_type">>    => <<"initiate_sale">>,
        <<"sale_id">>         => Cmd#initiate_sale_v1.sale_id,
        <<"seller_id">>       => Cmd#initiate_sale_v1.seller_id,
        <<"procurement_id">>  => Cmd#initiate_sale_v1.procurement_id,
        <<"offering_id">>     => Cmd#initiate_sale_v1.offering_id,
        <<"plugin_id">>       => Cmd#initiate_sale_v1.plugin_id
    }.

-spec from_map(map()) -> {ok, initiate_sale_v1()} | {error, term()}.
from_map(Map) ->
    SellerId      = hecate_api_utils:get_field(seller_id, Map),
    ProcurementId = hecate_api_utils:get_field(procurement_id, Map),
    OfferingId    = hecate_api_utils:get_field(offering_id, Map),
    PluginId      = hecate_api_utils:get_field(plugin_id, Map),
    case {SellerId, ProcurementId, OfferingId, PluginId} of
        {undefined, _, _, _} -> {error, missing_required_fields};
        {_, undefined, _, _} -> {error, missing_required_fields};
        {_, _, undefined, _} -> {error, missing_required_fields};
        {_, _, _, undefined} -> {error, missing_required_fields};
        _ ->
            SaleId = <<"sale-", SellerId/binary, "-", PluginId/binary>>,
            {ok, #initiate_sale_v1{
                sale_id        = SaleId,
                seller_id      = SellerId,
                procurement_id = ProcurementId,
                offering_id    = OfferingId,
                plugin_id      = PluginId
            }}
    end.

%% Accessors
-spec get_sale_id(initiate_sale_v1()) -> binary().
get_sale_id(#initiate_sale_v1{sale_id = V}) -> V.

-spec get_seller_id(initiate_sale_v1()) -> binary().
get_seller_id(#initiate_sale_v1{seller_id = V}) -> V.

-spec get_procurement_id(initiate_sale_v1()) -> binary().
get_procurement_id(#initiate_sale_v1{procurement_id = V}) -> V.

-spec get_offering_id(initiate_sale_v1()) -> binary().
get_offering_id(#initiate_sale_v1{offering_id = V}) -> V.

-spec get_plugin_id(initiate_sale_v1()) -> binary().
get_plugin_id(#initiate_sale_v1{plugin_id = V}) -> V.
