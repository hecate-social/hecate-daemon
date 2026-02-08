%%% @doc maybe_complete_discovery handler
%%% Business logic for completing the discovery phase.
%%% Validates the command and dispatches via evoq.
-module(maybe_complete_discovery).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle complete_discovery_v1 command (business logic only)
-spec handle(complete_discovery_v1:complete_discovery_v1()) ->
    {ok, [discovery_completed_v1:discovery_completed_v1()]} | {error, term()}.
handle(Cmd) ->
    CartwheelId = complete_discovery_v1:get_cartwheel_id(Cmd),
    case validate_command(CartwheelId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(complete_discovery_v1:complete_discovery_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CartwheelId = complete_discovery_v1:get_cartwheel_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(CartwheelId, Timestamp),
        command_type = complete_discovery,
        aggregate_type = cartwheel_aggregate,
        aggregate_id = <<"alc-", CartwheelId/binary>>,
        payload = complete_discovery_v1:to_map(Cmd),
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

validate_command(CartwheelId) when is_binary(CartwheelId), byte_size(CartwheelId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_command}.

create_event(Cmd) ->
    discovery_completed_v1:new(#{
        cartwheel_id => complete_discovery_v1:get_cartwheel_id(Cmd)
    }).

generate_command_id(CartwheelId, Timestamp) ->
    Hash = crypto:hash(sha256, <<CartwheelId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
