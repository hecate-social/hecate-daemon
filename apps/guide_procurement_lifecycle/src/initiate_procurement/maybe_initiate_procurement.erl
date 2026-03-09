%%% @doc maybe_initiate_procurement handler
%%% Business logic for initiating procurements.
%%% Validates the command and dispatches via evoq.
-module(maybe_initiate_procurement).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(initiate_procurement_v1:initiate_procurement_v1()) ->
    {ok, [procurement_initiated_v1:procurement_initiated_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(initiate_procurement_v1:initiate_procurement_v1(), term()) ->
    {ok, [procurement_initiated_v1:procurement_initiated_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    ConsumerId = initiate_procurement_v1:get_consumer_id(Cmd),
    OfferingId = initiate_procurement_v1:get_offering_id(Cmd),
    PluginId = initiate_procurement_v1:get_plugin_id(Cmd),
    case validate_command(ConsumerId, OfferingId, PluginId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(initiate_procurement_v1:initiate_procurement_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    ProcurementId = initiate_procurement_v1:get_procurement_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = initiate_procurement,
        aggregate_type = procurement_aggregate,
        aggregate_id = ProcurementId,
        payload = initiate_procurement_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => procurement_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => procurements_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(ConsumerId, OfferingId, PluginId) when
    is_binary(ConsumerId), byte_size(ConsumerId) > 0,
    is_binary(OfferingId), byte_size(OfferingId) > 0,
    is_binary(PluginId), byte_size(PluginId) > 0 ->
    ok;
validate_command(ConsumerId, _OfferingId, _PluginId) when
    not is_binary(ConsumerId); byte_size(ConsumerId) =:= 0 ->
    {error, invalid_consumer_id};
validate_command(_ConsumerId, OfferingId, _PluginId) when
    not is_binary(OfferingId); byte_size(OfferingId) =:= 0 ->
    {error, invalid_offering_id};
validate_command(_ConsumerId, _OfferingId, _PluginId) ->
    {error, invalid_plugin_id}.

create_event(Cmd) ->
    procurement_initiated_v1:new(#{
        procurement_id => initiate_procurement_v1:get_procurement_id(Cmd),
        consumer_id => initiate_procurement_v1:get_consumer_id(Cmd),
        offering_id => initiate_procurement_v1:get_offering_id(Cmd),
        plugin_id => initiate_procurement_v1:get_plugin_id(Cmd),
        author_id => initiate_procurement_v1:get_author_id(Cmd)
    }).
