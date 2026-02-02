%%% @doc maybe_announce_capability handler
%%% Business logic for announcing capabilities.
%%% Validates the command and dispatches via evoq.
-module(maybe_announce_capability).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
%% and opaque type usage in dispatch/1
-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle announce_capability_v1 command (business logic only)
%% Returns {ok, Events}
%% TODO: Add validation that may return {error, Reason}
-spec handle(announce_capability_v1:announce_capability_v1()) ->
    {ok, [capability_announced_v1:capability_announced_v1()]}.
handle(Cmd) ->
    %% TODO: Check if capability already exists (query aggregate state)
    %% TODO: Validate agent has permission to announce (check UCAN)
    Event = create_event_from_command(Cmd),
    {ok, [Event]}.

%% @doc Dispatch command via evoq (self-contained slice)
-spec dispatch(announce_capability_v1:announce_capability_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    MRI = announce_capability_v1:get_mri(Cmd),
    Timestamp = announce_capability_v1:get_announced_at(Cmd),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(MRI, Timestamp),
        command_type = announce_capability,
        aggregate_type = capability_aggregate,
        aggregate_id = MRI,
        payload = announce_capability_v1:to_map(Cmd),
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
    MRI = announce_capability_v1:get_mri(Cmd),
    AgentID = announce_capability_v1:get_agent_id(Cmd),
    Tags = announce_capability_v1:get_tags(Cmd),
    Desc = announce_capability_v1:get_description(Cmd),
    DemoProc = announce_capability_v1:get_demo_procedure(Cmd),
    Metadata = announce_capability_v1:get_metadata(Cmd),

    capability_announced_v1:new(MRI, AgentID, Tags, Desc, DemoProc, Metadata).

generate_command_id(MRI, Timestamp) ->
    Hash = crypto:hash(sha256, <<MRI/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
