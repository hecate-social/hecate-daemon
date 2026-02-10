-module(maybe_design_aggregate).
-export([handle/1, handle/2, dispatch/1]).
-include_lib("evoq/include/evoq.hrl").

-dialyzer({nowarn_function, [dispatch/1]}).

handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case design_aggregate_v1:validate(Cmd) of
        ok ->
            AggregateName = design_aggregate_v1:get_aggregate_name(Cmd),
            DesignedAggregates = maps:get(designed_aggregates, Context, #{}),
            case maps:is_key(AggregateName, DesignedAggregates) of
                true ->
                    {error, aggregate_already_designed};
                false ->
                    Event = aggregate_designed_v1:new(#{
                        division_id => design_aggregate_v1:get_division_id(Cmd),
                        aggregate_name => AggregateName,
                        stream_pattern => design_aggregate_v1:get_stream_pattern(Cmd),
                        status_flags => design_aggregate_v1:get_status_flags(Cmd),
                        description => design_aggregate_v1:get_description(Cmd),
                        designed_by => design_aggregate_v1:get_designed_by(Cmd)
                    }),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = design_aggregate_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_id = generate_command_id(DivisionId, Timestamp),
        command_type = design_aggregate,
        aggregate_type = design_aggregate,
        aggregate_id = DivisionId,
        payload = design_aggregate_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => design_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => design_division_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).

generate_command_id(DivisionId, Timestamp) ->
    Hash = crypto:hash(sha256, <<DivisionId/binary, (integer_to_binary(Timestamp))/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
