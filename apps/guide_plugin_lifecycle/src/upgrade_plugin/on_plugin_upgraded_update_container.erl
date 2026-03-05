%%% @doc Process Manager: On plugin upgraded, update the container image.
%%%
%%% Subscribes to plugin_upgraded_v1 events from plugins_store.
%%% Reads the existing .container Quadlet file, updates the Image= line
%%% with the new OCI image, and writes it back.
%%% @end
-module(on_plugin_upgraded_update_container).
-behaviour(gen_server).

-include_lib("reckon_gater/include/esdb_gater_types.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(EVENT_TYPE, <<"plugin_upgraded_v1">>).
-define(SUB_NAME, <<"on_plugin_upgraded_update_container">>).
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

%% Internal

handle_event(Event) ->
    Map = projection_event:to_map(Event),
    PluginId = get_value(plugin_id, Map),
    OciImage = get_value(oci_image, Map),
    Name = extract_plugin_name(PluginId),
    AppsDir = shared_paths:gitops_apps_dir(),
    FilePath = filename:join(AppsDir, container_filename(Name)),
    case file:read_file(FilePath) of
        {ok, Content} ->
            Updated = update_image_line(Content, OciImage),
            case file:write_file(FilePath, Updated) of
                ok ->
                    logger:info("[PM] Updated container image for ~s to ~s",
                                [PluginId, OciImage]),
                    ServiceName = service_name(Name),
                    case shared_systemctl:reload_and_start(ServiceName) of
                        ok ->
                            logger:info("[PM] Restarted service ~s", [ServiceName]);
                        {error, SvcErr} ->
                            logger:error("[PM] Failed to restart service ~s: ~p",
                                         [ServiceName, SvcErr])
                    end;
                {error, WriteErr} ->
                    logger:error("[PM] Failed to write updated container ~s: ~p",
                                 [FilePath, WriteErr])
            end;
        {error, enoent} ->
            logger:warning("[PM] Container file not found for ~s at ~s, skipping upgrade",
                           [PluginId, FilePath]);
        {error, ReadErr} ->
            logger:error("[PM] Failed to read container file ~s: ~p",
                         [FilePath, ReadErr])
    end.

%% @private Replace the Image= line in a .container file with a new OCI image.
update_image_line(Content, NewImage) ->
    Lines = binary:split(Content, <<"\n">>, [global]),
    Updated = lists:map(fun(Line) ->
        case binary:match(Line, <<"Image=">>) of
            {0, _} -> <<"Image=", NewImage/binary>>;
            _ -> Line
        end
    end, Lines),
    iolist_to_binary(lists:join(<<"\n">>, Updated)).

%% @private Extract the plugin name from a plugin_id like "hecate-social/trader".
extract_plugin_name(PluginId) ->
    case binary:split(PluginId, <<"/">>) of
        [_, Name] -> Name;
        [Name] -> Name
    end.

%% @private Build the .container filename for a plugin.
container_filename(Name) ->
    <<"hecate-", Name/binary, "d.container">>.

%% @private Build the systemd service name for a plugin.
service_name(Name) ->
    <<"hecate-", Name/binary, "d.service">>.

%% @private Get a value from a map, trying atom key first, then binary.
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
