%%% @doc maybe_resume_big_picture_storm handler
%%% Business logic for resuming a shelved Big Picture Event Storming session.
-module(maybe_resume_big_picture_storm).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


handle(Cmd) -> handle(Cmd, #{}).

handle(Cmd, _Context) ->
    case resume_big_picture_storm_v1:validate(Cmd) of
        ok ->
            Event = big_picture_storm_resumed_v1:new(#{
                venture_id => resume_big_picture_storm_v1:get_venture_id(Cmd)
            }),
            {ok, [Event]};
        {error, _} = Err -> Err
    end.

dispatch(Cmd) ->
    VentureId = resume_big_picture_storm_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = resume_big_picture_storm,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = resume_big_picture_storm_v1:to_map(Cmd),
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
