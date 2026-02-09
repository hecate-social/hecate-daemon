%%% @doc maybe_archive_torch handler
%%% Business logic for archiving torches.
%%% Validates the command and dispatches via evoq.
-module(maybe_archive_torch).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle archive_torch_v1 command (business logic only)
%% Returns list of events to emit.
-spec handle(archive_torch_v1:archive_torch_v1()) ->
    {ok, [torch_archived_v1:torch_archived_v1()]} | {error, term()}.
handle(Cmd) ->
    TorchId = archive_torch_v1:get_torch_id(Cmd),
    case validate_command(TorchId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB, enforces aggregate guards)
-spec dispatch(archive_torch_v1:archive_torch_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    TorchId = archive_torch_v1:get_torch_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(TorchId, Timestamp),
        command_type = archive_torch,
        aggregate_type = torch_aggregate,
        aggregate_id = TorchId,
        payload = archive_torch_v1:to_map(Cmd),
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
    torch_archived_v1:new(#{
        torch_id => archive_torch_v1:get_torch_id(Cmd),
        archived_by => archive_torch_v1:get_archived_by(Cmd),
        reason => archive_torch_v1:get_reason(Cmd)
    }).

generate_command_id(TorchId, Timestamp) ->
    Hash = crypto:hash(sha256, <<TorchId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
