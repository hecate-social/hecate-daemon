%%% @doc maybe_create_folder handler
%%% Business logic for creating folders in the briefcase.
-module(maybe_create_folder).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

%% @doc Handle create_folder_v1 command (business logic only)
-spec handle(create_folder_v1:create_folder_v1()) ->
    {ok, [folder_initiated_v1:folder_initiated_v1()]} | {error, term()}.
handle(Cmd) ->
    case create_folder_v1:validate(Cmd) of
        {ok, _} ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(create_folder_v1:create_folder_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    FolderId = create_folder_v1:get_folder_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = create_folder,
        aggregate_type = folder_aggregate,
        aggregate_id = FolderId,
        payload = create_folder_v1:to_map(Cmd),
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
    Icon = case create_folder_v1:get_icon(Cmd) of
        undefined -> <<"\xF0\x9F\x93\x81">>;
        I -> I
    end,
    folder_initiated_v1:new(#{
        folder_id => create_folder_v1:get_folder_id(Cmd),
        name      => create_folder_v1:get_name(Cmd),
        parent_id => create_folder_v1:get_parent_id(Cmd),
        icon      => Icon
    }).
