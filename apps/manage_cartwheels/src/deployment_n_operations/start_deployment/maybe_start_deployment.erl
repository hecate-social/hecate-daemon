%%% @doc maybe_start_deployment handler
%%% Business logic for starting the deployment and operations phase.
%%% Validates the command and dispatches via evoq.
-module(maybe_start_deployment).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle start_deployment_v1 command (business logic only)
-spec handle(start_deployment_v1:start_deployment_v1()) ->
    {ok, [deployment_started_v1:deployment_started_v1()]} | {error, term()}.
handle(Cmd) ->
    CartwheelId = start_deployment_v1:get_cartwheel_id(Cmd),
    case validate_command(CartwheelId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(start_deployment_v1:start_deployment_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CartwheelId = start_deployment_v1:get_cartwheel_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(CartwheelId, Timestamp),
        command_type = start_deployment,
        aggregate_type = cartwheel_aggregate,
        aggregate_id = <<"alc-", CartwheelId/binary>>,
        payload = start_deployment_v1:to_map(Cmd),
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

validate_command(CartwheelId) when
    is_binary(CartwheelId), byte_size(CartwheelId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_command}.

create_event(Cmd) ->
    deployment_started_v1:new(#{
        cartwheel_id => start_deployment_v1:get_cartwheel_id(Cmd)
    }).

generate_command_id(CartwheelId, Timestamp) ->
    Hash = crypto:hash(sha256, <<CartwheelId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
