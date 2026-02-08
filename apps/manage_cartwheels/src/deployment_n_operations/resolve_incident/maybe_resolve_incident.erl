%%% @doc maybe_resolve_incident handler
%%% Business logic for resolving an incident.
%%% Validates the command and dispatches via evoq.
-module(maybe_resolve_incident).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle resolve_incident_v1 command (business logic only)
-spec handle(resolve_incident_v1:resolve_incident_v1()) ->
    {ok, [incident_resolved_v1:incident_resolved_v1()]} | {error, term()}.
handle(Cmd) ->
    CartwheelId = resolve_incident_v1:get_cartwheel_id(Cmd),
    IncidentId = resolve_incident_v1:get_incident_id(Cmd),
    Resolution = resolve_incident_v1:get_resolution(Cmd),
    case validate_command(CartwheelId, IncidentId, Resolution) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(resolve_incident_v1:resolve_incident_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CartwheelId = resolve_incident_v1:get_cartwheel_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(CartwheelId, Timestamp),
        command_type = resolve_incident,
        aggregate_type = cartwheel_aggregate,
        aggregate_id = <<"alc-", CartwheelId/binary>>,
        payload = resolve_incident_v1:to_map(Cmd),
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

validate_command(CartwheelId, IncidentId, Resolution) when
    is_binary(CartwheelId), byte_size(CartwheelId) > 0,
    is_binary(IncidentId), byte_size(IncidentId) > 0,
    is_binary(Resolution), byte_size(Resolution) > 0 ->
    ok;
validate_command(_, _, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    incident_resolved_v1:new(#{
        cartwheel_id => resolve_incident_v1:get_cartwheel_id(Cmd),
        incident_id => resolve_incident_v1:get_incident_id(Cmd),
        resolution => resolve_incident_v1:get_resolution(Cmd)
    }).

generate_command_id(CartwheelId, Timestamp) ->
    Hash = crypto:hash(sha256, <<CartwheelId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
