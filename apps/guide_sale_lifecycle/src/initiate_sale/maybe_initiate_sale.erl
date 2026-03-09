%%% @doc maybe_initiate_sale handler
%%% Business logic for initiating sales.
%%% Validates the command and dispatches via evoq.
-module(maybe_initiate_sale).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(initiate_sale_v1:initiate_sale_v1()) ->
    {ok, [sale_initiated_v1:sale_initiated_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(initiate_sale_v1:initiate_sale_v1(), term()) ->
    {ok, [sale_initiated_v1:sale_initiated_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    SellerId      = initiate_sale_v1:get_seller_id(Cmd),
    ProcurementId = initiate_sale_v1:get_procurement_id(Cmd),
    OfferingId    = initiate_sale_v1:get_offering_id(Cmd),
    PluginId      = initiate_sale_v1:get_plugin_id(Cmd),
    case validate_command(SellerId, ProcurementId, OfferingId, PluginId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(initiate_sale_v1:initiate_sale_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    SaleId = initiate_sale_v1:get_sale_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = initiate_sale,
        aggregate_type = sale_aggregate,
        aggregate_id = SaleId,
        payload = initiate_sale_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => sale_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => sales_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(SellerId, ProcurementId, OfferingId, PluginId) when
    is_binary(SellerId), byte_size(SellerId) > 0,
    is_binary(ProcurementId), byte_size(ProcurementId) > 0,
    is_binary(OfferingId), byte_size(OfferingId) > 0,
    is_binary(PluginId), byte_size(PluginId) > 0 ->
    ok;
validate_command(SellerId, _ProcurementId, _OfferingId, _PluginId) when
    not is_binary(SellerId); byte_size(SellerId) =:= 0 ->
    {error, invalid_seller_id};
validate_command(_SellerId, ProcurementId, _OfferingId, _PluginId) when
    not is_binary(ProcurementId); byte_size(ProcurementId) =:= 0 ->
    {error, invalid_procurement_id};
validate_command(_SellerId, _ProcurementId, OfferingId, _PluginId) when
    not is_binary(OfferingId); byte_size(OfferingId) =:= 0 ->
    {error, invalid_offering_id};
validate_command(_SellerId, _ProcurementId, _OfferingId, _PluginId) ->
    {error, invalid_plugin_id}.

create_event(Cmd) ->
    sale_initiated_v1:new(#{
        sale_id        => initiate_sale_v1:get_sale_id(Cmd),
        seller_id      => initiate_sale_v1:get_seller_id(Cmd),
        procurement_id => initiate_sale_v1:get_procurement_id(Cmd),
        offering_id    => initiate_sale_v1:get_offering_id(Cmd),
        plugin_id      => initiate_sale_v1:get_plugin_id(Cmd)
    }).
