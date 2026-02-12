%%% @doc maybe_identify_division handler
%%% Business logic for identifying divisions during discovery.
%%% Takes Cmd and Context (#{discovered_divisions}) to check for duplicates.
-module(maybe_identify_division).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, Context) ->
    case identify_division_v1:validate(Cmd) of
        ok ->
            ContextName = identify_division_v1:get_context_name(Cmd),
            Discovered = maps:get(discovered_divisions, Context, #{}),
            case maps:is_key(ContextName, Discovered) of
                true ->
                    {error, division_already_identified};
                false ->
                    Event = division_identified_v1:new(#{
                        venture_id => identify_division_v1:get_venture_id(Cmd),
                        context_name => ContextName,
                        description => identify_division_v1:get_description(Cmd),
                        identified_by => identify_division_v1:get_identified_by(Cmd)
                    }),
                    {ok, [Event]}
            end;
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = identify_division_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = identify_division,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = identify_division_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => venture_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => dev_studio_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
