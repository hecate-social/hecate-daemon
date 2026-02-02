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
%% Validates MRI format, agent identity, and tags before creating event.
-spec handle(announce_capability_v1:announce_capability_v1()) ->
    {ok, [capability_announced_v1:capability_announced_v1()]} |
    {error, invalid_mri | invalid_mri_type | invalid_agent_identity | invalid_tags}.
handle(Cmd) ->
    MRI = announce_capability_v1:get_mri(Cmd),
    AgentID = announce_capability_v1:get_agent_id(Cmd),
    Tags = announce_capability_v1:get_tags(Cmd),

    case validate_command(MRI, AgentID, Tags) of
        ok ->
            Event = create_event_from_command(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Validate command fields
-spec validate_command(binary(), binary(), [binary()]) ->
    ok | {error, invalid_mri | invalid_mri_type | invalid_agent_identity | invalid_tags}.
validate_command(MRI, AgentID, Tags) ->
    case capability_validation:validate_mri(MRI) of
        ok ->
            case capability_validation:validate_agent_identity(AgentID) of
                ok ->
                    capability_validation:validate_tags(Tags);
                Error ->
                    Error
            end;
        Error ->
            Error
    end.

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
