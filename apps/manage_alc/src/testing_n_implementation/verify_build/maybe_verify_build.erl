%%% @doc maybe_verify_build handler
%%% Business logic for verifying a build during testing and implementation.
%%% Validates the command and dispatches via evoq.
-module(maybe_verify_build).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle verify_build_v1 command (business logic only)
-spec handle(verify_build_v1:verify_build_v1()) ->
    {ok, [build_verified_v1:build_verified_v1()]} | {error, term()}.
handle(Cmd) ->
    ProjectId = verify_build_v1:get_project_id(Cmd),
    Result = verify_build_v1:get_result(Cmd),
    case validate_command(ProjectId, Result) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(verify_build_v1:verify_build_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    ProjectId = verify_build_v1:get_project_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(ProjectId, Timestamp),
        command_type = verify_build,
        aggregate_type = alc_aggregate,
        aggregate_id = <<"alc-", ProjectId/binary>>,
        payload = verify_build_v1:to_map(Cmd),
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

validate_command(ProjectId, Result) when
    is_binary(ProjectId), byte_size(ProjectId) > 0,
    is_binary(Result), byte_size(Result) > 0 ->
    ok;
validate_command(_, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    build_verified_v1:new(#{
        project_id => verify_build_v1:get_project_id(Cmd),
        build_id => verify_build_v1:get_build_id(Cmd),
        result => verify_build_v1:get_result(Cmd),
        notes => verify_build_v1:get_notes(Cmd)
    }).

generate_command_id(ProjectId, Timestamp) ->
    Hash = crypto:hash(sha256, <<ProjectId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
