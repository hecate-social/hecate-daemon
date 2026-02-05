%%% @doc maybe_start_architecture handler
%%% Business logic for starting the architecture and planning phase.
%%% Validates the command and dispatches via evoq.
-module(maybe_start_architecture).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle start_architecture_v1 command (business logic only)
-spec handle(start_architecture_v1:start_architecture_v1()) ->
    {ok, [architecture_started_v1:architecture_started_v1()]} | {error, term()}.
handle(Cmd) ->
    ProjectId = start_architecture_v1:get_project_id(Cmd),
    case validate_command(ProjectId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(start_architecture_v1:start_architecture_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    ProjectId = start_architecture_v1:get_project_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(ProjectId, Timestamp),
        command_type = start_architecture,
        aggregate_type = alc_aggregate,
        aggregate_id = <<"alc-", ProjectId/binary>>,
        payload = start_architecture_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => alc_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => manage_alc_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(ProjectId) when is_binary(ProjectId), byte_size(ProjectId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_command}.

create_event(Cmd) ->
    architecture_started_v1:new(#{
        project_id => start_architecture_v1:get_project_id(Cmd)
    }).

generate_command_id(ProjectId, Timestamp) ->
    Hash = crypto:hash(sha256, <<ProjectId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
