%%% @doc maybe_report_incident handler
%%% Business logic for reporting an incident.
%%% Validates the command and dispatches via evoq.
-module(maybe_report_incident).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

%% @doc Handle report_incident_v1 command (business logic only)
-spec handle(report_incident_v1:report_incident_v1()) ->
    {ok, [incident_reported_v1:incident_reported_v1()]} | {error, term()}.
handle(Cmd) ->
    CartwheelId = report_incident_v1:get_cartwheel_id(Cmd),
    Description = report_incident_v1:get_description(Cmd),
    case validate_command(CartwheelId, Description) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq
-spec dispatch(report_incident_v1:report_incident_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CartwheelId = report_incident_v1:get_cartwheel_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(CartwheelId, Timestamp),
        command_type = report_incident,
        aggregate_type = cartwheel_aggregate,
        aggregate_id = <<"alc-", CartwheelId/binary>>,
        payload = report_incident_v1:to_map(Cmd),
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

validate_command(CartwheelId, Description) when
    is_binary(CartwheelId), byte_size(CartwheelId) > 0,
    is_binary(Description), byte_size(Description) > 0 ->
    ok;
validate_command(_, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    incident_reported_v1:new(#{
        cartwheel_id => report_incident_v1:get_cartwheel_id(Cmd),
        incident_id => report_incident_v1:get_incident_id(Cmd),
        severity => report_incident_v1:get_severity(Cmd),
        description => report_incident_v1:get_description(Cmd)
    }).

generate_command_id(CartwheelId, Timestamp) ->
    Hash = crypto:hash(sha256, <<CartwheelId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
