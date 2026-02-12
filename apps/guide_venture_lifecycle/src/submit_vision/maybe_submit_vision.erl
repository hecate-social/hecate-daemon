%%% @doc maybe_submit_vision handler
%%% Business logic for submitting (finalizing) venture vision.
-module(maybe_submit_vision).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).


%% @doc Handle submit_vision_v1 command (business logic only)
-spec handle(submit_vision_v1:submit_vision_v1()) ->
    {ok, [vision_submitted_v1:vision_submitted_v1()]} | {error, term()}.
handle(Cmd) ->
    VentureId = submit_vision_v1:get_venture_id(Cmd),
    case validate_command(VentureId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB, enforces aggregate guards)
-spec dispatch(submit_vision_v1:submit_vision_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    VentureId = submit_vision_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = submit_vision,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = submit_vision_v1:to_map(Cmd),
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

%% Internal

validate_command(VentureId) when is_binary(VentureId), byte_size(VentureId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_venture_id}.

create_event(Cmd) ->
    vision_submitted_v1:new(#{
        venture_id => submit_vision_v1:get_venture_id(Cmd)
    }).
