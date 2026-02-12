%%% @doc maybe_archive_division handler
%%% Business logic for archiving divisions.
-module(maybe_archive_division).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).


handle(Cmd) ->
    DivisionId = archive_division_v1:get_division_id(Cmd),
    case validate_command(DivisionId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

dispatch(Cmd) ->
    DivisionId = archive_division_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = archive_division,
        aggregate_type = division_aggregate,
        aggregate_id = DivisionId,
        payload = archive_division_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => division_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => dev_studio_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(DivisionId) when is_binary(DivisionId), byte_size(DivisionId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_division_id}.

create_event(Cmd) ->
    division_archived_v1:new(#{
        division_id => archive_division_v1:get_division_id(Cmd),
        reason => archive_division_v1:get_reason(Cmd)
    }).
