%%% @doc maybe_initiate_cartwheel handler
%%% Business logic for initiating cartwheels.
%%% Validates the command and dispatches via evoq.
-module(maybe_initiate_cartwheel).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle initiate_cartwheel_v1 command (business logic only)
-spec handle(initiate_cartwheel_v1:initiate_cartwheel_v1()) ->
    {ok, [cartwheel_initiated_v1:cartwheel_initiated_v1()]} | {error, term()}.
handle(Cmd) ->
    Name = initiate_cartwheel_v1:get_context_name(Cmd),
    case validate_command(Name) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(initiate_cartwheel_v1:initiate_cartwheel_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CartwheelId = initiate_cartwheel_v1:get_cartwheel_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(CartwheelId, Timestamp),
        command_type = initiate_cartwheel,
        aggregate_type = cartwheel_aggregate,
        aggregate_id = <<"cartwheel-", CartwheelId/binary>>,
        payload = initiate_cartwheel_v1:to_map(Cmd),
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

validate_command(Name) when is_binary(Name), byte_size(Name) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_command}.

create_event(Cmd) ->
    cartwheel_initiated_v1:new(#{
        cartwheel_id => initiate_cartwheel_v1:get_cartwheel_id(Cmd),
        torch_id => initiate_cartwheel_v1:get_torch_id(Cmd),
        context_name => initiate_cartwheel_v1:get_context_name(Cmd),
        description => initiate_cartwheel_v1:get_description(Cmd)
    }).

generate_command_id(CartwheelId, Timestamp) ->
    Hash = crypto:hash(sha256, <<CartwheelId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
