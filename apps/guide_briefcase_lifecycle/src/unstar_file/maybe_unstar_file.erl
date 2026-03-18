%%% @doc maybe_unstar_file handler
%%% Business logic for unstarring files.
-module(maybe_unstar_file).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

%% @doc Handle unstar_file_v1 command (business logic only)
-spec handle(unstar_file_v1:unstar_file_v1()) ->
    {ok, [file_unstarred_v1:file_unstarred_v1()]} | {error, term()}.
handle(Cmd) ->
    case unstar_file_v1:validate(Cmd) of
        {ok, _} ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(unstar_file_v1:unstar_file_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    FileId = unstar_file_v1:get_file_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = unstar_file,
        aggregate_type = file_aggregate,
        aggregate_id = FileId,
        payload = unstar_file_v1:to_map(Cmd),
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
    file_unstarred_v1:new(#{
        file_id => unstar_file_v1:get_file_id(Cmd)
    }).
