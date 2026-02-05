%%% @doc maybe_initiate_project handler
%%% Business logic for initiating projects.
%%% Validates the command and dispatches via evoq.
-module(maybe_initiate_project).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle initiate_project_v1 command (business logic only)
-spec handle(initiate_project_v1:initiate_project_v1()) ->
    {ok, [project_initiated_v1:project_initiated_v1()]} | {error, term()}.
handle(Cmd) ->
    Name = initiate_project_v1:get_name(Cmd),
    case validate_command(Name) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(initiate_project_v1:initiate_project_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    ProjectId = initiate_project_v1:get_project_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(ProjectId, Timestamp),
        command_type = initiate_project,
        aggregate_type = alc_aggregate,
        aggregate_id = <<"alc-", ProjectId/binary>>,
        payload = initiate_project_v1:to_map(Cmd),
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

validate_command(Name) when is_binary(Name), byte_size(Name) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_command}.

create_event(Cmd) ->
    project_initiated_v1:new(#{
        project_id => initiate_project_v1:get_project_id(Cmd),
        name => initiate_project_v1:get_name(Cmd),
        description => initiate_project_v1:get_description(Cmd)
    }).

generate_command_id(ProjectId, Timestamp) ->
    Hash = crypto:hash(sha256, <<ProjectId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
