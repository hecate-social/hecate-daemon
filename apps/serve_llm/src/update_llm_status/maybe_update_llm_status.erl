%%% @doc maybe_update_llm_status handler
%%% Business logic for updating LLM capability status.
-module(maybe_update_llm_status).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle update_llm_status_v1 command (business logic only)
-spec handle(update_llm_status_v1:update_llm_status_v1()) ->
    {ok, [llm_status_updated_v1:llm_status_updated_v1()]}.
handle(Cmd) ->
    CapabilityMRI = update_llm_status_v1:get_capability_mri(Cmd),
    ModelName = update_llm_status_v1:get_model_name(Cmd),
    AgentID = update_llm_status_v1:get_agent_id(Cmd),
    QueueDepth = update_llm_status_v1:get_queue_depth(Cmd),
    AvgTokensPerSec = update_llm_status_v1:get_avg_tokens_per_sec(Cmd),
    Available = update_llm_status_v1:get_available(Cmd),

    %% Create the domain event
    Event = llm_status_updated_v1:new(
        CapabilityMRI, ModelName, AgentID, QueueDepth, AvgTokensPerSec, Available
    ),
    {ok, [Event]}.

%% @doc Dispatch command via evoq (self-contained slice)
-spec dispatch(update_llm_status_v1:update_llm_status_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CapabilityMRI = update_llm_status_v1:get_capability_mri(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(CapabilityMRI, Timestamp),
        command_type = update_llm_status,
        aggregate_type = llm_capability_aggregate,
        aggregate_id = CapabilityMRI,
        payload = update_llm_status_v1:to_map(Cmd),
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
    <<"cmd-llm-status-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
