%%% @doc maybe_archive_folder handler
%%% Business logic for archiving folders.
-module(maybe_archive_folder).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

%% @doc Handle archive_folder_v1 command (business logic only)
-spec handle(archive_folder_v1:archive_folder_v1()) ->
    {ok, [folder_archived_v1:folder_archived_v1()]} | {error, term()}.
handle(Cmd) ->
    case archive_folder_v1:validate(Cmd) of
        {ok, _} ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(archive_folder_v1:archive_folder_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    FolderId = archive_folder_v1:get_folder_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = archive_folder,
        aggregate_type = folder_aggregate,
        aggregate_id = FolderId,
        payload = archive_folder_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => folder_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => briefcase_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

create_event(Cmd) ->
    folder_archived_v1:new(#{
        folder_id => archive_folder_v1:get_folder_id(Cmd)
    }).
