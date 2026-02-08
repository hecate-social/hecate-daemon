%%% @doc maybe_initiate_torch handler
%%% Business logic for initiating torches.
%%% Validates the command and dispatches via evoq.
-module(maybe_initiate_torch).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle initiate_torch_v1 command (business logic only)
-spec handle(initiate_torch_v1:initiate_torch_v1()) ->
    {ok, [torch_initiated_v1:torch_initiated_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(initiate_torch_v1:initiate_torch_v1(), term()) ->
    {ok, [torch_initiated_v1:torch_initiated_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    Name = initiate_torch_v1:get_name(Cmd),
    case validate_command(Name) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(initiate_torch_v1:initiate_torch_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    TorchId = initiate_torch_v1:get_torch_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(TorchId, Timestamp),
        command_type = initiate_torch,
        aggregate_type = torch_aggregate,
        aggregate_id = <<"torch-", TorchId/binary>>,
        payload = initiate_torch_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => torch_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => manage_torches_store,
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
    torch_initiated_v1:new(#{
        torch_id => initiate_torch_v1:get_torch_id(Cmd),
        name => initiate_torch_v1:get_name(Cmd),
        brief => initiate_torch_v1:get_brief(Cmd),
        initiated_by => initiate_torch_v1:get_initiated_by(Cmd)
    }).

generate_command_id(TorchId, Timestamp) ->
    Hash = crypto:hash(sha256, <<TorchId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
