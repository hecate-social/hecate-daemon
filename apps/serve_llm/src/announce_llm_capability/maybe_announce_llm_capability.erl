%%% @doc maybe_announce_llm_capability handler
%%% Business logic for announcing LLM capabilities.
%%% Validates the command and dispatches via evoq.
-module(maybe_announce_llm_capability).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle announce_llm_capability_v1 command (business logic only)
%% Always succeeds - validation is done at command creation.
-spec handle(announce_llm_capability_v1:announce_llm_capability_v1()) ->
    {ok, [llm_capability_announced_v1:llm_capability_announced_v1()]}.
handle(Cmd) ->
    ModelName = announce_llm_capability_v1:get_model_name(Cmd),
    AgentID = announce_llm_capability_v1:get_agent_id(Cmd),
    CapabilityMRI = announce_llm_capability_v1:get_capability_mri(Cmd),
    ModelSize = announce_llm_capability_v1:get_model_size(Cmd),
    Quantization = announce_llm_capability_v1:get_quantization(Cmd),
    ContextLength = announce_llm_capability_v1:get_context_length(Cmd),
    Metadata = announce_llm_capability_v1:get_metadata(Cmd),

    %% Create the domain event
    Event = llm_capability_announced_v1:new(
        ModelName, AgentID, CapabilityMRI,
        ModelSize, Quantization, ContextLength, Metadata
    ),
    {ok, [Event]}.

%% @doc Dispatch command via evoq (self-contained slice)
-spec dispatch(announce_llm_capability_v1:announce_llm_capability_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CapabilityMRI = announce_llm_capability_v1:get_capability_mri(Cmd),
    Timestamp = announce_llm_capability_v1:get_announced_at(Cmd),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(CapabilityMRI, Timestamp),
        command_type = announce_llm_capability,
        aggregate_type = llm_capability_aggregate,
        aggregate_id = CapabilityMRI,
        payload = announce_llm_capability_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => llm_capability_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => serve_llm_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal functions

generate_command_id(MRI, Timestamp) ->
    Hash = crypto:hash(sha256, <<MRI/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-llm-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
