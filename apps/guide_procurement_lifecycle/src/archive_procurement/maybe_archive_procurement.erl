%%% @doc maybe_archive_procurement handler
%%% Business logic for archiving procurements.
-module(maybe_archive_procurement).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(archive_procurement_v1:archive_procurement_v1()) ->
    {ok, [procurement_archived_v1:procurement_archived_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(archive_procurement_v1:archive_procurement_v1(), term()) ->
    {ok, [procurement_archived_v1:procurement_archived_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    ProcurementId = archive_procurement_v1:get_procurement_id(Cmd),
    case validate_command(ProcurementId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(archive_procurement_v1:archive_procurement_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    ProcurementId = archive_procurement_v1:get_procurement_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = archive_procurement,
        aggregate_type = procurement_aggregate,
        aggregate_id = ProcurementId,
        payload = archive_procurement_v1:to_map(Cmd),
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

validate_command(ProcurementId) when is_binary(ProcurementId), byte_size(ProcurementId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_procurement_id}.

create_event(Cmd) ->
    procurement_archived_v1:new(#{
        procurement_id => archive_procurement_v1:get_procurement_id(Cmd)
    }).
