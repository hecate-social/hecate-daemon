%%% @doc maybe_retract_capability handler
%%% Business logic for retracting capabilities.
%%% Validates the command and dispatches via evoq.
-module(maybe_retract_capability).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
%% and opaque type usage in dispatch/1
-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle retract_capability_v1 command (business logic only)
%% Returns {ok, Events}
%% TODO: Add validation that may return {error, Reason}
-spec handle(retract_capability_v1:retract_capability_v1()) ->
    {ok, [capability_retracted_v1:capability_retracted_v1()]}.
handle(Cmd) ->
    %% TODO: Validate agent has permission to retract (must be owner)
    Event = create_event_from_command(Cmd),
    {ok, [Event]}.

%% @doc Dispatch command via evoq (self-contained slice)
-spec dispatch(retract_capability_v1:retract_capability_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    MRI = retract_capability_v1:get_mri(Cmd),
    Timestamp = retract_capability_v1:get_retracted_at(Cmd),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(MRI, Timestamp),
        command_type = retract_capability,
        aggregate_type = capability_aggregate,
        aggregate_id = MRI,
        payload = retract_capability_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => capability_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => manage_capabilities_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal functions

create_event_from_command(Cmd) ->
    MRI = retract_capability_v1:get_mri(Cmd),
    AgentID = retract_capability_v1:get_agent_id(Cmd),
    Reason = retract_capability_v1:get_reason(Cmd),

    capability_retracted_v1:new(MRI, AgentID, Reason).

generate_command_id(MRI, Timestamp) ->
    Hash = crypto:hash(sha256, <<MRI/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-ret-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
