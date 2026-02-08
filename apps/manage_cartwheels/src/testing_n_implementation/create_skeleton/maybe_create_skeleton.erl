%%% @doc maybe_create_skeleton handler
%%% Business logic for creating a skeleton during testing and implementation.
%%% Validates the command and dispatches via evoq.
-module(maybe_create_skeleton).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle create_skeleton_v1 command (business logic only)
-spec handle(create_skeleton_v1:create_skeleton_v1()) ->
    {ok, [skeleton_created_v1:skeleton_created_v1()]} | {error, term()}.
handle(Cmd) ->
    CartwheelId = create_skeleton_v1:get_cartwheel_id(Cmd),
    case validate_command(CartwheelId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(create_skeleton_v1:create_skeleton_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CartwheelId = create_skeleton_v1:get_cartwheel_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(CartwheelId, Timestamp),
        command_type = create_skeleton,
        aggregate_type = cartwheel_aggregate,
        aggregate_id = <<"alc-", CartwheelId/binary>>,
        payload = create_skeleton_v1:to_map(Cmd),
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
    skeleton_created_v1:new(#{
        cartwheel_id => create_skeleton_v1:get_cartwheel_id(Cmd),
        skeleton_id => create_skeleton_v1:get_skeleton_id(Cmd),
        description => create_skeleton_v1:get_description(Cmd)
    }).

generate_command_id(CartwheelId, Timestamp) ->
    Hash = crypto:hash(sha256, <<CartwheelId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
