%%% @doc maybe_star_file handler
%%% Business logic for starring files.
-module(maybe_star_file).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

%% @doc Handle star_file_v1 command (business logic only)
-spec handle(star_file_v1:star_file_v1()) ->
    {ok, [file_starred_v1:file_starred_v1()]} | {error, term()}.
handle(Cmd) ->
    case star_file_v1:validate(Cmd) of
        {ok, _} ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(star_file_v1:star_file_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    FileId = star_file_v1:get_file_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = star_file,
        aggregate_type = file_aggregate,
        aggregate_id = FileId,
        payload = star_file_v1:to_map(Cmd),
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
    file_starred_v1:new(#{
        file_id => star_file_v1:get_file_id(Cmd)
    }).
