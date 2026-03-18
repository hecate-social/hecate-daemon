%%% @doc maybe_move_folder handler
%%% Business logic for moving folders.
-module(maybe_move_folder).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

%% @doc Handle move_folder_v1 command (business logic only)
-spec handle(move_folder_v1:move_folder_v1()) ->
    {ok, [folder_moved_v1:folder_moved_v1()]} | {error, term()}.
handle(Cmd) ->
    case move_folder_v1:validate(Cmd) of
        {ok, _} ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(move_folder_v1:move_folder_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    FolderId = move_folder_v1:get_folder_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = move_folder,
        aggregate_type = folder_aggregate,
        aggregate_id = FolderId,
        payload = move_folder_v1:to_map(Cmd),
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
    folder_moved_v1:new(#{
        folder_id => move_folder_v1:get_folder_id(Cmd),
        parent_id => move_folder_v1:get_parent_id(Cmd)
    }).
