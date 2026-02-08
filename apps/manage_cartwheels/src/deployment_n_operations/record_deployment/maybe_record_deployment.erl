%%% @doc maybe_record_deployment handler
%%% Business logic for recording a deployment.
%%% Validates the command and dispatches via evoq.
-module(maybe_record_deployment).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle record_deployment_v1 command (business logic only)
-spec handle(record_deployment_v1:record_deployment_v1()) ->
    {ok, [deployment_recorded_v1:deployment_recorded_v1()]} | {error, term()}.
handle(Cmd) ->
    CartwheelId = record_deployment_v1:get_cartwheel_id(Cmd),
    Environment = record_deployment_v1:get_environment(Cmd),
    Version = record_deployment_v1:get_version(Cmd),
    case validate_command(CartwheelId, Environment, Version) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(record_deployment_v1:record_deployment_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CartwheelId = record_deployment_v1:get_cartwheel_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(CartwheelId, Timestamp),
        command_type = record_deployment,
        aggregate_type = cartwheel_aggregate,
        aggregate_id = <<"alc-", CartwheelId/binary>>,
        payload = record_deployment_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => cartwheel_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => manage_cartwheels_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(CartwheelId, Environment, Version) when
    is_binary(CartwheelId), byte_size(CartwheelId) > 0,
    is_binary(Environment), byte_size(Environment) > 0,
    is_binary(Version), byte_size(Version) > 0 ->
    ok;
validate_command(_, _, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    deployment_recorded_v1:new(#{
        cartwheel_id => record_deployment_v1:get_cartwheel_id(Cmd),
        deployment_id => record_deployment_v1:get_deployment_id(Cmd),
        environment => record_deployment_v1:get_environment(Cmd),
        version => record_deployment_v1:get_version(Cmd),
        notes => record_deployment_v1:get_notes(Cmd)
    }).

generate_command_id(CartwheelId, Timestamp) ->
    Hash = crypto:hash(sha256, <<CartwheelId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
