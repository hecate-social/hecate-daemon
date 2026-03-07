%%% @doc maybe_track_llm_call handler
%%% Validates and dispatches LLM call tracking via evoq.
-module(maybe_track_llm_call).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-spec handle(track_llm_call_v1:track_llm_call_v1()) ->
    {ok, [llm_call_tracked_v1:llm_call_tracked_v1()]} | {error, term()}.
handle(Cmd) ->
    case track_llm_call_v1:validate(Cmd) of
        {ok, _} ->
            CmdMap = track_llm_call_v1:to_map(Cmd),
            Event = llm_call_tracked_v1:new(#{
                venture_id  => maps:get(<<"venture_id">>, CmdMap),
                division_id => maps:get(<<"division_id">>, CmdMap),
                agent_id    => maps:get(<<"agent_id">>, CmdMap),
                task_id     => maps:get(<<"task_id">>, CmdMap),
                model       => maps:get(<<"model">>, CmdMap),
                tokens_in   => maps:get(<<"tokens_in">>, CmdMap),
                tokens_out  => maps:get(<<"tokens_out">>, CmdMap),
                cost_usd    => maps:get(<<"cost_usd">>, CmdMap)
            }),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(map()) -> {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Data) when is_map(Data) ->
    VentureId = maps:get(venture_id, Data, maps:get(<<"venture_id">>, Data, <<"default">>)),

    EvoqCmd = #evoq_command{
        command_type = track_llm_call,
        aggregate_type = llm_usage_aggregate,
        aggregate_id = VentureId,
        payload = #{
            <<"command_type">> => <<"track_llm_call">>,
            <<"venture_id">>   => VentureId,
            <<"division_id">>  => maps:get(division_id, Data, maps:get(<<"division_id">>, Data, undefined)),
            <<"agent_id">>     => maps:get(agent_id, Data, maps:get(<<"agent_id">>, Data, undefined)),
            <<"task_id">>      => maps:get(task_id, Data, maps:get(<<"task_id">>, Data, undefined)),
            <<"model">>        => maps:get(model, Data, maps:get(<<"model">>, Data, <<>>)),
            <<"tokens_in">>    => maps:get(tokens_in, Data, maps:get(<<"tokens_in">>, Data, 0)),
            <<"tokens_out">>   => maps:get(tokens_out, Data, maps:get(<<"tokens_out">>, Data, 0)),
            <<"cost_usd">>     => maps:get(cost_usd, Data, maps:get(<<"cost_usd">>, Data, undefined))
        },
        metadata = #{timestamp => erlang:system_time(millisecond)},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => llm_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).
