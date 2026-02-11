-module(maybe_record_health_status).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").

-dialyzer({nowarn_function, [dispatch/1]}).

handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case record_health_status_v1:validate(Cmd) of
        ok ->
            CheckId = record_health_status_v1:get_check_id(Cmd),
            HealthChecks = maps:get(health_checks, Context, #{}),
            case maps:is_key(CheckId, HealthChecks) of
                false ->
                    {error, health_check_not_found};
                true ->
                    Event = health_status_recorded_v1:new(#{
                        division_id => record_health_status_v1:get_division_id(Cmd),
                        check_id => CheckId,
                        status => record_health_status_v1:get_status(Cmd),
                        latency_ms => record_health_status_v1:get_latency_ms(Cmd),
                        details => record_health_status_v1:get_details(Cmd)
                    }),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = record_health_status_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_id = generate_command_id(DivisionId, Timestamp),
        command_type = record_health_status,
        aggregate_type = monitoring_aggregate,
        aggregate_id = DivisionId,
        payload = record_health_status_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => monitoring_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => monitor_division_store,
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
