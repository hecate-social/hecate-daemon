%%% @doc Process Manager: On plugin installed, register a launcher entry.
%%%
%%% Subscribes to plugin_installed_v1 events from plugins_store.
%%% Dispatches register_entry_v1 to add the plugin to the launcher
%%% under the "PLUGINS" group.
%%% @end
-module(on_plugin_installed_register_entry).
-behaviour(gen_server).

-include_lib("evoq/include/evoq_types.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(EVENT_TYPE, <<"plugin_installed_v1">>).
-define(SUB_NAME, <<"on_plugin_installed_register_entry">>).
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
    EntryId = Name,
    DisplayName = Name,
    Icon = <<"\xF0\x9F\x94\x8C">>,
    GroupName = <<"PLUGINS">>,
    CmdParams = #{
        entry_id     => EntryId,
        display_name => DisplayName,
        icon         => Icon,
        group_name   => GroupName
    },
    case register_entry_v1:new(CmdParams) of
        {ok, Cmd} ->
            case maybe_register_entry:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[PM] Registered launcher entry ~s for plugin ~s",
                                [EntryId, PluginId]);
                {error, entry_already_registered} ->
                    logger:info("[PM] Launcher entry ~s already exists, skipping",
                                [EntryId]);
                {error, launcher_not_initialized} ->
                    logger:warning("[PM] Launcher not initialized, cannot register ~s",
                                   [EntryId]);
                {error, Reason} ->
                    logger:error("[PM] Failed to register launcher entry ~s: ~p",
                                 [EntryId, Reason])
            end;
        {error, Reason} ->
            logger:error("[PM] Invalid register_entry command for ~s: ~p",
                         [PluginId, Reason])
    end.

%% @private Get a value from a map, trying atom key first, then binary.
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
