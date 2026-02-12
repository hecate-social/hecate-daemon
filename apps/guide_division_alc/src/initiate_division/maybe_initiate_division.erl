%%% @doc maybe_initiate_division handler
%%% Business logic for initiating divisions.
%%% Validates the command and dispatches via evoq.
-module(maybe_initiate_division).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


%% @doc Handle initiate_division_v1 command (business logic only)
-spec handle(initiate_division_v1:initiate_division_v1()) ->
    {ok, [division_initiated_v1:division_initiated_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(initiate_division_v1:initiate_division_v1(), term()) ->
    {ok, [division_initiated_v1:division_initiated_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    VentureId = initiate_division_v1:get_venture_id(Cmd),
    ContextName = initiate_division_v1:get_context_name(Cmd),
    case validate_command(VentureId, ContextName) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(initiate_division_v1:initiate_division_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    DivisionId = initiate_division_v1:get_division_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = initiate_division,
        aggregate_type = division_aggregate,
        aggregate_id = DivisionId,
        payload = initiate_division_v1:to_map(Cmd),
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

%% Internal

validate_command(VentureId, ContextName) when
    is_binary(VentureId), byte_size(VentureId) > 0,
    is_binary(ContextName), byte_size(ContextName) > 0 ->
    ok;
validate_command(_, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    division_initiated_v1:new(#{
        division_id => initiate_division_v1:get_division_id(Cmd),
        venture_id => initiate_division_v1:get_venture_id(Cmd),
        context_name => initiate_division_v1:get_context_name(Cmd),
        initiated_by => initiate_division_v1:get_initiated_by(Cmd)
    }).
