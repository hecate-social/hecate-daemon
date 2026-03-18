%%% @doc maybe_import_file handler
%%% Business logic for importing raw files with blob data.
-module(maybe_import_file).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

%% @doc Handle import_file_v1 command (business logic only)
-spec handle(import_file_v1:import_file_v1()) ->
    {ok, [file_imported_v1:file_imported_v1()]} | {error, term()}.
handle(Cmd) ->
    case import_file_v1:validate(Cmd) of
        {ok, _} ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(import_file_v1:import_file_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    FileId = import_file_v1:get_file_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = import_file,
        aggregate_type = file_aggregate,
        aggregate_id = FileId,
        payload = import_file_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => file_aggregate},
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
    file_imported_v1:new(#{
        file_id   => import_file_v1:get_file_id(Cmd),
        name      => import_file_v1:get_name(Cmd),
        folder_id => import_file_v1:get_folder_id(Cmd),
        file_type => import_file_v1:get_file_type(Cmd),
        plugin    => import_file_v1:get_plugin(Cmd),
        icon      => import_file_v1:get_icon(Cmd),
        blob_id   => import_file_v1:get_blob_id(Cmd),
        size      => import_file_v1:get_size(Cmd),
        mime_type => import_file_v1:get_mime_type(Cmd)
    }).
