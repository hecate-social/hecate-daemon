%%% @doc maybe_implement_spoke handler
%%% Business logic for implementing a spoke during testing and implementation.
%%% Validates the command and dispatches via evoq.
-module(maybe_implement_spoke).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle implement_spoke_v1 command (business logic only)
-spec handle(implement_spoke_v1:implement_spoke_v1()) ->
    {ok, [spoke_implemented_v1:spoke_implemented_v1()]} | {error, term()}.
handle(Cmd) ->
    CartwheelId = implement_spoke_v1:get_cartwheel_id(Cmd),
    SpokeId = implement_spoke_v1:get_spoke_id(Cmd),
    case validate_command(CartwheelId, SpokeId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(implement_spoke_v1:implement_spoke_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CartwheelId = implement_spoke_v1:get_cartwheel_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(CartwheelId, Timestamp),
        command_type = implement_spoke,
        aggregate_type = cartwheel_aggregate,
        aggregate_id = <<"alc-", CartwheelId/binary>>,
        payload = implement_spoke_v1:to_map(Cmd),
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

validate_command(CartwheelId, SpokeId) when
    is_binary(CartwheelId), byte_size(CartwheelId) > 0,
    is_binary(SpokeId), byte_size(SpokeId) > 0 ->
    ok;
validate_command(_, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    spoke_implemented_v1:new(#{
        cartwheel_id => implement_spoke_v1:get_cartwheel_id(Cmd),
        implementation_id => implement_spoke_v1:get_implementation_id(Cmd),
        spoke_id => implement_spoke_v1:get_spoke_id(Cmd),
        implementation_notes => implement_spoke_v1:get_implementation_notes(Cmd)
    }).

generate_command_id(CartwheelId, Timestamp) ->
    Hash = crypto:hash(sha256, <<CartwheelId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
