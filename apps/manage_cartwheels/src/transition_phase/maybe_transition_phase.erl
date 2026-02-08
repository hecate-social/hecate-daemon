%%% @doc maybe_transition_phase handler
%%% Business logic for transitioning an ALC project between phases.
%%% Validates the command and dispatches via evoq.
-module(maybe_transition_phase).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle transition_phase_v1 command (business logic only)
-spec handle(transition_phase_v1:transition_phase_v1()) ->
    {ok, [phase_transitioned_v1:phase_transitioned_v1()]} | {error, term()}.
handle(Cmd) ->
    CartwheelId = transition_phase_v1:get_cartwheel_id(Cmd),
    FromPhase = transition_phase_v1:get_from_phase(Cmd),
    ToPhase = transition_phase_v1:get_to_phase(Cmd),
    case validate_command(CartwheelId, FromPhase, ToPhase) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(transition_phase_v1:transition_phase_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CartwheelId = transition_phase_v1:get_cartwheel_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(CartwheelId, Timestamp),
        command_type = transition_phase,
        aggregate_type = cartwheel_aggregate,
        aggregate_id = <<"alc-", CartwheelId/binary>>,
        payload = transition_phase_v1:to_map(Cmd),
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

validate_command(CartwheelId, FromPhase, ToPhase) when
    is_binary(CartwheelId), byte_size(CartwheelId) > 0,
    is_binary(FromPhase), byte_size(FromPhase) > 0,
    is_binary(ToPhase), byte_size(ToPhase) > 0 ->
    ok;
validate_command(_, _, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    phase_transitioned_v1:new(#{
        cartwheel_id => transition_phase_v1:get_cartwheel_id(Cmd),
        from_phase => transition_phase_v1:get_from_phase(Cmd),
        to_phase => transition_phase_v1:get_to_phase(Cmd)
    }).

generate_command_id(CartwheelId, Timestamp) ->
    Hash = crypto:hash(sha256, <<CartwheelId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
