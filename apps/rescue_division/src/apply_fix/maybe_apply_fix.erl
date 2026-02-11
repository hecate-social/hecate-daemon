-module(maybe_apply_fix).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").

-dialyzer({nowarn_function, [dispatch/1]}).

handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case apply_fix_v1:validate(Cmd) of
        ok ->
            Event = fix_applied_v1:new(#{
                division_id => apply_fix_v1:get_division_id(Cmd),
                incident_id => apply_fix_v1:get_incident_id(Cmd),
                diagnosis_id => apply_fix_v1:get_diagnosis_id(Cmd),
                fix_description => apply_fix_v1:get_fix_description(Cmd),
                fix_type => apply_fix_v1:get_fix_type(Cmd),
                applied_by => apply_fix_v1:get_applied_by(Cmd)
            }),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = apply_fix_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_id = generate_command_id(DivisionId, Timestamp),
        command_type = apply_fix,
        aggregate_type = rescue_aggregate,
        aggregate_id = DivisionId,
        payload = apply_fix_v1:to_map(Cmd),
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
