%%% @doc Process Manager: On plugin removed, unregister the launcher entry.
%%%
%%% Subscribes to plugin_removed_v1 events from plugins_store.
%%% Dispatches unregister_entry_v1 to remove the plugin from the launcher.
%%% @end
-module(on_plugin_removed_unregister_entry).
-behaviour(gen_server).

-include_lib("evoq/include/evoq_types.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(EVENT_TYPE, <<"plugin_removed_v1">>).
-define(SUB_NAME, <<"on_plugin_removed_unregister_entry">>).
-define(STORE_ID, plugins_store).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, _} = evoq_subscriptions:subscribe(
        ?STORE_ID, event_type, ?EVENT_TYPE, ?SUB_NAME,
        #{subscriber_pid => self()}),
    {ok, #{}}.

handle_info({events, Events}, State) ->
    lists:foreach(fun(E) -> handle_event(E) end, Events),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

%% Internal — event handling

handle_event(#evoq_event{data = Data}) ->
    PluginId = get_value(plugin_id, Data),
    Name = get_value(name, Data),
    EntryId = case Name of
        undefined -> PluginId;
        _ -> Name
    end,
    CmdParams = #{entry_id => EntryId},
    case unregister_entry_v1:new(CmdParams) of
        {ok, Cmd} ->
            case maybe_unregister_entry:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[PM] Unregistered launcher entry ~s for plugin ~s",
                                [EntryId, PluginId]);
                {error, entry_not_found} ->
                    logger:info("[PM] Launcher entry ~s not found, skipping",
                                [EntryId]);
                {error, launcher_not_initialized} ->
                    logger:warning("[PM] Launcher not initialized, cannot unregister ~s",
                                   [EntryId]);
                {error, Reason} ->
                    logger:error("[PM] Failed to unregister launcher entry ~s: ~p",
                                 [EntryId, Reason])
            end;
        {error, Reason} ->
            logger:error("[PM] Invalid unregister_entry command for ~s: ~p",
                         [PluginId, Reason])
    end.

%% @private Get a value from a map, trying atom key first, then binary.
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
