%%% @doc maybe_design_aggregate handler
%%% Business logic for designing aggregates within a division.
-module(maybe_design_aggregate).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case design_aggregate_v1:validate(Cmd) of
        {ok, _} ->
            AggregateName = design_aggregate_v1:get_aggregate_name(Cmd),
            DesignedAggregates = maps:get(designed_aggregates, Context, #{}),
            case maps:is_key(AggregateName, DesignedAggregates) of
                true ->
                    {error, aggregate_already_designed};
                false ->
                    Event = aggregate_designed_v1:new(#{
                        division_id => design_aggregate_v1:get_division_id(Cmd),
                        aggregate_name => AggregateName,
                        description => design_aggregate_v1:get_description(Cmd),
                        stream_prefix => design_aggregate_v1:get_stream_prefix(Cmd),
                        fields => design_aggregate_v1:get_fields(Cmd)
                    }),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    DivisionId = design_aggregate_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = design_aggregate,
        aggregate_type = division_aggregate,
        aggregate_id = DivisionId,
        payload = design_aggregate_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => division_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => dev_studio_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).
