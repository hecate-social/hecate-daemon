%%% @doc Process Manager: On plugin upgraded, update the container image.
%%%
%%% Subscribes to plugin_upgraded_v1 events via evoq_event_handler.
%%% Reads the existing .container Quadlet file, updates the Image= line
%%% with the new OCI image, and writes it back.
%%% @end
-module(on_plugin_upgraded_update_container).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"plugin_upgraded_v1">>].

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    do_handle(Data),
    {ok, State}.

%% Internal

do_handle(Data) ->
    PluginId = get_value(plugin_id, Data),
    OciImage = get_value(oci_image, Data),
    DaemonName = extract_daemon_name(OciImage),
    AppsDir = shared_paths:gitops_apps_dir(),
    FilePath = filename:join(AppsDir, container_filename(DaemonName)),
    case file:read_file(FilePath) of
        {ok, Content} ->
            Updated = update_image_line(Content, OciImage),
            case file:write_file(FilePath, Updated) of
                ok ->
                    logger:info("[PM] Updated container image for ~s to ~s",
                                [PluginId, OciImage]),
                    ServiceName = service_name(DaemonName),
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

%% @private Extract the daemon name from the OCI image reference.
extract_daemon_name(OciImage) ->
    Base = strip_tag(OciImage),
    case split_last(Base, <<"/">>) of
        {_, Name} -> Name;
        nomatch -> Base
    end.

strip_tag(Image) ->
    case split_last(Image, <<":">>) of
        {Base, Tag} ->
            case binary:match(Tag, <<"/">>) of
                nomatch -> Base;
                _ -> Image
            end;
        nomatch -> Image
    end.

split_last(Bin, Sep) ->
    case binary:matches(Bin, Sep) of
        [] -> nomatch;
        Matches ->
            {Pos, Len} = lists:last(Matches),
            {binary:part(Bin, 0, Pos), binary:part(Bin, Pos + Len, byte_size(Bin) - Pos - Len)}
    end.

%% @private Build the .container filename.
container_filename(DaemonName) ->
    <<DaemonName/binary, ".container">>.

%% @private Build the systemd service name.
service_name(DaemonName) ->
    <<DaemonName/binary, ".service">>.

%% @private Get a value from a map, trying atom key first, then binary.
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
