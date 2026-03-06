%%% @doc maybe_unregister_entry handler
%%% Business logic for removing an app entry from the launcher.
%%% Validates that the entry exists in at least one group.
-module(maybe_unregister_entry).

-include_lib("evoq/include/evoq.hrl").
-include("launcher_state.hrl").

-export([handle/1, handle/2, dispatch/1]).

%% @doc Handle unregister_entry_v1 command (business logic only, no state)
-spec handle(unregister_entry_v1:unregister_entry_v1()) ->
    {ok, [entry_unregistered_v1:entry_unregistered_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(unregister_entry_v1:unregister_entry_v1(), term()) ->
    {ok, [entry_unregistered_v1:entry_unregistered_v1()]} | {error, term()}.
handle(Cmd, undefined) ->
    create_event(Cmd);
handle(Cmd, #launcher_state{groups = Groups}) ->
    EntryId = unregister_entry_v1:get_entry_id(Cmd),
    case entry_exists(EntryId, Groups) of
        false ->
            {error, entry_not_found};
        true ->
            create_event(Cmd)
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(unregister_entry_v1:unregister_entry_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = unregister_entry,
        aggregate_type = launcher_aggregate,
        aggregate_id = <<"launcher">>,
        payload = unregister_entry_v1:to_map(Cmd),
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
    Event = entry_unregistered_v1:new(#{
        entry_id => unregister_entry_v1:get_entry_id(Cmd)
    }),
    {ok, [Event]}.

entry_exists(EntryId, Groups) ->
    lists:any(fun(Group) ->
        Apps = maps:get(apps, Group, maps:get(<<"apps">>, Group, [])),
        lists:member(EntryId, Apps)
    end, Groups).
