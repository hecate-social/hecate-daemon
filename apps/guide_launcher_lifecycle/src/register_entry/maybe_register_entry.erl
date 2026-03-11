%%% @doc maybe_register_entry handler
%%% Business logic for registering an app entry in the launcher.
%%% Validates entry_id is not empty, checks entry is not already registered.
-module(maybe_register_entry).

-include_lib("evoq/include/evoq.hrl").
-include("launcher_state.hrl").

-export([handle/1, handle/2, dispatch/1]).

%% @doc Handle register_entry_v1 command (business logic only, no state)
-spec handle(register_entry_v1:register_entry_v1()) ->
    {ok, [entry_registered_v1:entry_registered_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(register_entry_v1:register_entry_v1(), term()) ->
    {ok, [entry_registered_v1:entry_registered_v1()]} | {error, term()}.
handle(Cmd, undefined) ->
    create_event(Cmd);
handle(Cmd, #launcher_state{groups = Groups}) ->
    EntryId = register_entry_v1:get_entry_id(Cmd),
    case entry_exists(EntryId, Groups) of
        true ->
            {error, entry_already_registered};
        false ->
            create_event(Cmd)
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(register_entry_v1:register_entry_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = register_entry,
        aggregate_type = launcher_aggregate,
        aggregate_id = <<"launcher">>,
        payload = register_entry_v1:to_map(Cmd),
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

create_event(Cmd) ->
    Event = entry_registered_v1:new(#{
        entry_id     => register_entry_v1:get_entry_id(Cmd),
        display_name => register_entry_v1:get_display_name(Cmd),
        icon         => register_entry_v1:get_icon(Cmd),
        group_name   => register_entry_v1:get_group_name(Cmd),
        group_icon   => register_entry_v1:get_group_icon(Cmd)
    }),
    {ok, [Event]}.

entry_exists(EntryId, Groups) ->
    lists:any(fun(Group) ->
        Apps = maps:get(apps, Group, maps:get(<<"apps">>, Group, [])),
        lists:member(EntryId, Apps)
    end, Groups).
