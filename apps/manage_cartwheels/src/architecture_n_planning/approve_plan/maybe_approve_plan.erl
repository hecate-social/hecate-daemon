%%% @doc maybe_approve_plan handler
%%% Business logic for approving a plan during architecture and planning.
%%% Validates the command and dispatches via evoq.
-module(maybe_approve_plan).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle approve_plan_v1 command (business logic only)
-spec handle(approve_plan_v1:approve_plan_v1()) ->
    {ok, [plan_approved_v1:plan_approved_v1()]} | {error, term()}.
handle(Cmd) ->
    CartwheelId = approve_plan_v1:get_cartwheel_id(Cmd),
    PlanId = approve_plan_v1:get_plan_id(Cmd),
    case validate_command(CartwheelId, PlanId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(approve_plan_v1:approve_plan_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CartwheelId = approve_plan_v1:get_cartwheel_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(CartwheelId, Timestamp),
        command_type = approve_plan,
        aggregate_type = cartwheel_aggregate,
        aggregate_id = <<"alc-", CartwheelId/binary>>,
        payload = approve_plan_v1:to_map(Cmd),
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

validate_command(CartwheelId, PlanId) when
    is_binary(CartwheelId), byte_size(CartwheelId) > 0,
    is_binary(PlanId), byte_size(PlanId) > 0 ->
    ok;
validate_command(_, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    plan_approved_v1:new(#{
        cartwheel_id => approve_plan_v1:get_cartwheel_id(Cmd),
        plan_id => approve_plan_v1:get_plan_id(Cmd)
    }).

generate_command_id(CartwheelId, Timestamp) ->
    Hash = crypto:hash(sha256, <<CartwheelId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
