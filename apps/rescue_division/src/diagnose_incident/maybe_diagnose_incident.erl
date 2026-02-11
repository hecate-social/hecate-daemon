-module(maybe_diagnose_incident).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").

-dialyzer({nowarn_function, [dispatch/1]}).

handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case diagnose_incident_v1:validate(Cmd) of
        ok ->
            Event = incident_diagnosed_v1:new(#{
                division_id => diagnose_incident_v1:get_division_id(Cmd),
                incident_id => diagnose_incident_v1:get_incident_id(Cmd),
                diagnosis => diagnose_incident_v1:get_diagnosis(Cmd),
                root_cause => diagnose_incident_v1:get_root_cause(Cmd),
                diagnosed_by => diagnose_incident_v1:get_diagnosed_by(Cmd)
            }),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = diagnose_incident_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_id = generate_command_id(DivisionId, Timestamp),
        command_type = diagnose_incident,
        aggregate_type = rescue_aggregate,
        aggregate_id = DivisionId,
        payload = diagnose_incident_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => rescue_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => rescue_division_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).

generate_command_id(DivisionId, Timestamp) ->
    Unique = integer_to_binary(erlang:unique_integer([positive])),
    Hash = crypto:hash(sha256, <<DivisionId/binary, (integer_to_binary(Timestamp))/binary, "-", Unique/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
