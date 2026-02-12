%%% @doc maybe_initiate_venture handler
%%% Business logic for initiating ventures.
%%% Validates the command and dispatches via evoq.
-module(maybe_initiate_venture).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


%% @doc Handle initiate_venture_v1 command (business logic only)
-spec handle(initiate_venture_v1:initiate_venture_v1()) ->
    {ok, [venture_initiated_v1:venture_initiated_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(initiate_venture_v1:initiate_venture_v1(), term()) ->
    {ok, [venture_initiated_v1:venture_initiated_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    Name = initiate_venture_v1:get_name(Cmd),
    case validate_command(Name) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(initiate_venture_v1:initiate_venture_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    VentureId = initiate_venture_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = initiate_venture,
        aggregate_type = venture_aggregate,
        aggregate_id = VentureId,
        payload = initiate_venture_v1:to_map(Cmd),
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

validate_command(Name) when is_binary(Name), byte_size(Name) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_command}.

create_event(Cmd) ->
    venture_initiated_v1:new(#{
        venture_id => initiate_venture_v1:get_venture_id(Cmd),
        name => initiate_venture_v1:get_name(Cmd),
        brief => initiate_venture_v1:get_brief(Cmd),
        initiated_by => initiate_venture_v1:get_initiated_by(Cmd)
    }).
