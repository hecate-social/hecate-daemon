%%% @doc maybe_initiate_payment handler
%%% Business logic for initiating payments.
%%% Validates the command and dispatches via evoq.
-module(maybe_initiate_payment).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(initiate_payment_v1:initiate_payment_v1()) ->
    {ok, [payment_initiated_v1:payment_initiated_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(initiate_payment_v1:initiate_payment_v1(), term()) ->
    {ok, [payment_initiated_v1:payment_initiated_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    ConsumerId = initiate_payment_v1:get_consumer_id(Cmd),
    PluginId = initiate_payment_v1:get_plugin_id(Cmd),
    case validate_command(ConsumerId, PluginId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(initiate_payment_v1:initiate_payment_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    PaymentId = initiate_payment_v1:get_payment_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = initiate_payment,
        aggregate_type = payment_aggregate,
        aggregate_id = PaymentId,
        payload = initiate_payment_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => payment_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => payments_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(ConsumerId, PluginId) when
    is_binary(ConsumerId), byte_size(ConsumerId) > 0,
    is_binary(PluginId), byte_size(PluginId) > 0 ->
    ok;
validate_command(ConsumerId, _PluginId) when
    not is_binary(ConsumerId); byte_size(ConsumerId) =:= 0 ->
    {error, invalid_consumer_id};
validate_command(_ConsumerId, _PluginId) ->
    {error, invalid_plugin_id}.

create_event(Cmd) ->
    payment_initiated_v1:new(#{
        payment_id => initiate_payment_v1:get_payment_id(Cmd),
        consumer_id => initiate_payment_v1:get_consumer_id(Cmd),
        procurement_id => initiate_payment_v1:get_procurement_id(Cmd),
        offering_id => initiate_payment_v1:get_offering_id(Cmd),
        plugin_id => initiate_payment_v1:get_plugin_id(Cmd),
        amount_cents => initiate_payment_v1:get_amount_cents(Cmd),
        currency => initiate_payment_v1:get_currency(Cmd)
    }).
