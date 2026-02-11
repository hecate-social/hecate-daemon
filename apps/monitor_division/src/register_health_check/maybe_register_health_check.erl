-module(maybe_register_health_check).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case register_health_check_v1:validate(Cmd) of
        ok ->
            DivisionId = register_health_check_v1:get_division_id(Cmd),
            CheckName = register_health_check_v1:get_check_name(Cmd),
            CheckId = <<"check-", DivisionId/binary, "-", CheckName/binary>>,
            HealthChecks = maps:get(health_checks, Context, #{}),
            case maps:is_key(CheckId, HealthChecks) of
                true ->
                    {error, health_check_already_registered};
                false ->
                    Event = health_check_registered_v1:new(#{
                        division_id => DivisionId,
                        check_id => CheckId,
                        check_name => CheckName,
                        check_type => register_health_check_v1:get_check_type(Cmd),
                        endpoint => register_health_check_v1:get_endpoint(Cmd),
                        interval_ms => register_health_check_v1:get_interval_ms(Cmd)
                    }),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = register_health_check_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = register_health_check,
        aggregate_type = monitoring_aggregate,
        aggregate_id = DivisionId,
        payload = register_health_check_v1:to_map(Cmd),
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
