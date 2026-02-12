%%% @doc maybe_archive_venture handler
%%% Business logic for archiving ventures.
-module(maybe_archive_venture).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).


%% @doc Handle archive_venture_v1 command (business logic only)
-spec handle(archive_venture_v1:archive_venture_v1()) ->
    {ok, [venture_archived_v1:venture_archived_v1()]} | {error, term()}.
handle(Cmd) ->
    VentureId = archive_venture_v1:get_venture_id(Cmd),
    case validate_command(VentureId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB, enforces aggregate guards)
-spec dispatch(archive_venture_v1:archive_venture_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    VentureId = archive_venture_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = archive_venture,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = archive_venture_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => venture_aggregate},
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

validate_command(VentureId) when is_binary(VentureId), byte_size(VentureId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_venture_id}.

create_event(Cmd) ->
    venture_archived_v1:new(#{
        venture_id => archive_venture_v1:get_venture_id(Cmd),
        reason => archive_venture_v1:get_reason(Cmd)
    }).
