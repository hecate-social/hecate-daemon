%%% @doc maybe_archive_offering handler
%%% Business logic for archiving offerings.
-module(maybe_archive_offering).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(archive_offering_v1:archive_offering_v1()) ->
    {ok, [offering_archived_v1:offering_archived_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(archive_offering_v1:archive_offering_v1(), term()) ->
    {ok, [offering_archived_v1:offering_archived_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    OfferingId = archive_offering_v1:get_offering_id(Cmd),
    case validate_command(OfferingId) of
        ok ->
            Event = offering_archived_v1:new(#{offering_id => OfferingId}),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(archive_offering_v1:archive_offering_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    OfferingId = archive_offering_v1:get_offering_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = archive_offering,
        aggregate_type = license_offering_aggregate,
        aggregate_id = OfferingId,
        payload = archive_offering_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => license_offering_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => license_offerings_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(OfferingId) when
    is_binary(OfferingId), byte_size(OfferingId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_offering_id}.
