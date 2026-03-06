%%% @doc maybe_reorganize_launcher handler
%%% Business logic for full launcher layout reorganization.
%%% Validates groups is a list where each group has name and apps.
-module(maybe_reorganize_launcher).

-include_lib("evoq/include/evoq.hrl").
-include("launcher_state.hrl").

-export([handle/1, handle/2, dispatch/1]).

%% @doc Handle reorganize_launcher_v1 command (business logic only, no state)
-spec handle(reorganize_launcher_v1:reorganize_launcher_v1()) ->
    {ok, [launcher_reorganized_v1:launcher_reorganized_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(reorganize_launcher_v1:reorganize_launcher_v1(), term()) ->
    {ok, [launcher_reorganized_v1:launcher_reorganized_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    Groups = reorganize_launcher_v1:get_groups(Cmd),
    case validate_layout(Groups) of
        ok ->
            Event = launcher_reorganized_v1:new(#{groups => Groups}),
            {ok, [Event]};
        {error, _} = Err ->
            Err
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(reorganize_launcher_v1:reorganize_launcher_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = reorganize_launcher,
        aggregate_type = launcher_aggregate,
        aggregate_id = <<"launcher">>,
        payload = reorganize_launcher_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => launcher_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => launcher_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_layout(Groups) when is_list(Groups) ->
    validate_groups(Groups);
validate_layout(_) ->
    {error, groups_must_be_list}.

validate_groups([]) -> ok;
validate_groups([G | Rest]) when is_map(G) ->
    Name = maps:get(name, G, maps:get(<<"name">>, G, undefined)),
    Apps = maps:get(apps, G, maps:get(<<"apps">>, G, undefined)),
    case {Name, Apps} of
        {undefined, _} -> {error, group_missing_name};
        {_, undefined} -> {error, group_missing_apps};
        {_, _} when not is_list(Apps) -> {error, group_apps_not_list};
        _ -> validate_groups(Rest)
    end;
validate_groups([_ | _]) ->
    {error, group_not_map}.
