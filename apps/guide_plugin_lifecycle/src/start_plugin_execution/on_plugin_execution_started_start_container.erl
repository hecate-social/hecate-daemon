%%% @doc Process Manager: On plugin execution started, start the container.
%%%
%%% Subscribes to plugin_execution_started_v1 events from plugins_store.
%%% Calls shared_systemctl to start the plugin's systemd service.
-module(on_plugin_execution_started_start_container).
-behaviour(gen_server).

-include_lib("evoq/include/evoq_types.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(EVENT_TYPE, <<"plugin_execution_started_v1">>).
-define(SUB_NAME, <<"on_plugin_execution_started_start_container">>).
-define(STORE_ID, plugins_store).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, _} = evoq_subscriptions:subscribe(
        ?STORE_ID, event_type, ?EVENT_TYPE, ?SUB_NAME,
        #{subscriber_pid => self()}),
    {ok, #{}}.

handle_info({events, Events}, State) ->
    lists:foreach(fun handle_event/1, Events),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

%% Internal

handle_event(#evoq_event{data = Data}) ->
    PluginId = get_value(plugin_id, Data),
    start_container(PluginId).

start_container(PluginId) ->
    case resolve_daemon_name(PluginId) of
        undefined ->
            logger:error("[PM] Cannot resolve daemon name for plugin ~s", [PluginId]);
        DaemonName ->
            ServiceName = <<DaemonName/binary, ".service">>,
            case shared_systemctl:reload_and_start(ServiceName) of
                ok ->
                    logger:info("[PM] Started service ~s for plugin ~s",
                                [ServiceName, PluginId]);
                {error, Reason} ->
                    logger:error("[PM] Failed to start service ~s: ~p",
                                 [ServiceName, Reason])
            end
    end.

%% @private Look up oci_image from plugins read model, extract daemon name.
resolve_daemon_name(PluginId) ->
    Sql = "SELECT oci_image FROM plugins WHERE plugin_id = ?1 LIMIT 1",
    case project_plugins_store:query(Sql, [PluginId]) of
        {ok, [[OciImage]]} -> extract_daemon_name(OciImage);
        _ -> undefined
    end.

%% @private Extract daemon name from OCI image ref.
%% "ghcr.io/hecate-apps/hecate-app-snake-dueld:0.1.1" -> "hecate-app-snake-dueld"
extract_daemon_name(OciImage) ->
    Base = strip_tag(OciImage),
    case binary:matches(Base, <<"/">>) of
        [] -> Base;
        Matches ->
            {Pos, Len} = lists:last(Matches),
            binary:part(Base, Pos + Len, byte_size(Base) - Pos - Len)
    end.

strip_tag(Image) ->
    case binary:matches(Image, <<":">>) of
        [] -> Image;
        Matches ->
            {Pos, _} = lists:last(Matches),
            Tag = binary:part(Image, Pos + 1, byte_size(Image) - Pos - 1),
            case binary:match(Tag, <<"/">>) of
                nomatch -> binary:part(Image, 0, Pos);
                _ -> Image
            end
    end.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
