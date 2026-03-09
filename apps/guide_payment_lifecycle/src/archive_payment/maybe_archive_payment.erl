%%% @doc maybe_archive_payment handler
%%% Business logic for archiving payments.
-module(maybe_archive_payment).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(archive_payment_v1:archive_payment_v1()) ->
    {ok, [payment_archived_v1:payment_archived_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(archive_payment_v1:archive_payment_v1(), term()) ->
    {ok, [payment_archived_v1:payment_archived_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    PaymentId = archive_payment_v1:get_payment_id(Cmd),
    case validate_command(PaymentId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(archive_payment_v1:archive_payment_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    PaymentId = archive_payment_v1:get_payment_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = archive_payment,
        aggregate_type = payment_aggregate,
        aggregate_id = PaymentId,
        payload = archive_payment_v1:to_map(Cmd),
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

validate_command(PaymentId) when is_binary(PaymentId), byte_size(PaymentId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_payment_id}.

create_event(Cmd) ->
    payment_archived_v1:new(#{
        payment_id => archive_payment_v1:get_payment_id(Cmd)
    }).
