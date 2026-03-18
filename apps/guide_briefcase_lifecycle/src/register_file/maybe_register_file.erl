%%% @doc maybe_register_file handler
%%% Business logic for registering plugin-created files.
-module(maybe_register_file).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

%% @doc Handle register_file_v1 command (business logic only)
-spec handle(register_file_v1:register_file_v1()) ->
    {ok, [file_registered_v1:file_registered_v1()]} | {error, term()}.
handle(Cmd) ->
    case register_file_v1:validate(Cmd) of
        {ok, _} ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(register_file_v1:register_file_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    FileId = register_file_v1:get_file_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = register_file,
        aggregate_type = file_aggregate,
        aggregate_id = FileId,
        payload = register_file_v1:to_map(Cmd),
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
    file_registered_v1:new(#{
        file_id   => register_file_v1:get_file_id(Cmd),
        name      => register_file_v1:get_name(Cmd),
        folder_id => register_file_v1:get_folder_id(Cmd),
        file_type => register_file_v1:get_file_type(Cmd),
        plugin    => register_file_v1:get_plugin(Cmd),
        icon      => register_file_v1:get_icon(Cmd)
    }).
