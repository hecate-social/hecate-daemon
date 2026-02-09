%%% @doc maybe_submit_vision handler
%%% Business logic for submitting (finalizing) torch vision.
%%% Validates the command and dispatches via evoq.
-module(maybe_submit_vision).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle submit_vision_v1 command (business logic only)
%% Returns list of events to emit.
-spec handle(submit_vision_v1:submit_vision_v1()) ->
    {ok, [torch_vision_submitted_v1:torch_vision_submitted_v1()]} | {error, term()}.
handle(Cmd) ->
    TorchId = submit_vision_v1:get_torch_id(Cmd),
    case validate_command(TorchId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB, enforces aggregate guards)
-spec dispatch(submit_vision_v1:submit_vision_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    TorchId = submit_vision_v1:get_torch_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(TorchId, Timestamp),
        command_type = submit_vision,
        aggregate_type = torch_aggregate,
        aggregate_id = TorchId,
        payload = submit_vision_v1:to_map(Cmd),
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

validate_command(TorchId) when is_binary(TorchId), byte_size(TorchId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_torch_id}.

create_event(Cmd) ->
    torch_vision_submitted_v1:new(#{
        torch_id => submit_vision_v1:get_torch_id(Cmd),
        submitted_by => submit_vision_v1:get_submitted_by(Cmd)
    }).

generate_command_id(TorchId, Timestamp) ->
    Hash = crypto:hash(sha256, <<TorchId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
