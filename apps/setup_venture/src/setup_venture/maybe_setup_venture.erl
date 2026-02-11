%%% @doc maybe_setup_venture handler
%%% Business logic for setting up ventures.
%%% Validates the command and dispatches via evoq.
-module(maybe_setup_venture).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


%% @doc Handle setup_venture_v1 command (business logic only)
-spec handle(setup_venture_v1:setup_venture_v1()) ->
    {ok, [venture_setup_v1:venture_setup_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(setup_venture_v1:setup_venture_v1(), term()) ->
    {ok, [venture_setup_v1:venture_setup_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    Name = setup_venture_v1:get_name(Cmd),
    case validate_command(Name) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(setup_venture_v1:setup_venture_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    VentureId = setup_venture_v1:get_venture_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = setup_venture,
        aggregate_type = setup_aggregate,
        aggregate_id = VentureId,
        payload = setup_venture_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => setup_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => setup_venture_store,
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
    venture_setup_v1:new(#{
        venture_id => setup_venture_v1:get_venture_id(Cmd),
        name => setup_venture_v1:get_name(Cmd),
        brief => setup_venture_v1:get_brief(Cmd),
        initiated_by => setup_venture_v1:get_initiated_by(Cmd)
    }).
