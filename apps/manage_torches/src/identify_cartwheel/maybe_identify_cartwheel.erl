%%% @doc Handler for identify_cartwheel_v1 command
%%%
%%% Validates and processes cartwheel identification requests.
%%% Ensures the cartwheel name is unique within the torch.
%%% @end
-module(maybe_identify_cartwheel).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle the command without prior state (for API dispatch)
-spec handle(identify_cartwheel_v1:identify_cartwheel_v1()) ->
    {ok, [cartwheel_identified_v1:cartwheel_identified_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, #{}).

%% @doc Handle the command with aggregate state context
-spec handle(identify_cartwheel_v1:identify_cartwheel_v1(), map()) ->
    {ok, [cartwheel_identified_v1:cartwheel_identified_v1()]} | {error, term()}.
handle(Cmd, Context) ->
    case identify_cartwheel_v1:validate(Cmd) of
        {ok, ValidCmd} ->
            execute(ValidCmd, Context);
        {error, Reason} ->
            {error, Reason}
    end.

execute(Cmd, Context) ->
    TorchId = identify_cartwheel_v1:get_torch_id(Cmd),
    ContextName = identify_cartwheel_v1:get_context_name(Cmd),

    %% Check if this context name is already identified in this torch
    ExistingCartwheels = maps:get(identified_cartwheels, Context, #{}),
    case maps:is_key(ContextName, ExistingCartwheels) of
        true ->
            {error, cartwheel_already_identified};
        false ->
            create_event(TorchId, ContextName, Cmd)
    end.

create_event(TorchId, ContextName, Cmd) ->
    case cartwheel_identified_v1:new(#{
        torch_id => TorchId,
        context_name => ContextName,
        description => identify_cartwheel_v1:get_description(Cmd),
        identified_by => identify_cartwheel_v1:get_identified_by(Cmd)
    }) of
        {ok, Event} ->
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB, enforces aggregate guards)
-spec dispatch(identify_cartwheel_v1:identify_cartwheel_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    TorchId = identify_cartwheel_v1:get_torch_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(TorchId, Timestamp),
        command_type = identify_cartwheel,
        aggregate_type = torch_aggregate,
        aggregate_id = TorchId,
        payload = identify_cartwheel_v1:to_map(Cmd),
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

generate_command_id(TorchId, Timestamp) ->
    Hash = crypto:hash(sha256, <<TorchId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
