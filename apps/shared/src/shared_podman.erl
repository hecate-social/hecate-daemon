%%% @doc Podman operations for plugin containers.
%%%
%%% Provides OCI image pulling with progress tracking,
%%% and container file provisioning helpers.
%%% @end
-module(shared_podman).

-export([pull_image/2]).
-export([render_container/2, container_filename/1, extract_daemon_name/1, strip_tag/1]).

%% @doc Pull an OCI image via `podman pull`, sending progress messages to CallbackPid.
%%
%% Progress messages:
%%   {pull_progress, #{status => downloading | extracting | complete | error,
%%                     line => binary()}}
%%   {pull_done, ok}
%%   {pull_done, {error, Reason}}
-spec pull_image(binary(), pid()) -> ok | {error, term()}.
pull_image(Image, CallbackPid) ->
    Cmd = iolist_to_binary(["podman pull ", Image]),
    Port = open_port({spawn, binary_to_list(Cmd)},
                     [stream, binary, exit_status, stderr_to_stdout, {line, 4096}]),
    pull_loop(Port, CallbackPid, <<>>).

pull_loop(Port, Pid, Buf) ->
    receive
        {Port, {data, {eol, Line}}} ->
            Status = parse_pull_line(Line),
            Pid ! {pull_progress, #{status => Status, line => Line}},
            pull_loop(Port, Pid, <<>>);
        {Port, {data, {noeol, Chunk}}} ->
            pull_loop(Port, Pid, <<Buf/binary, Chunk/binary>>);
        {Port, {exit_status, 0}} ->
            Pid ! {pull_done, ok},
            ok;
        {Port, {exit_status, Code}} ->
            Reason = {exit_code, Code},
            Pid ! {pull_done, {error, Reason}},
            {error, Reason}
    after 600000 ->
        catch port_close(Port),
        Pid ! {pull_done, {error, timeout}},
        {error, timeout}
    end.

parse_pull_line(Line) ->
    case Line of
        <<"Copying blob ", _/binary>> -> downloading;
        <<"Copying config ", _/binary>> -> downloading;
        <<"Writing manifest", _/binary>> -> extracting;
        <<"Storing signatures", _/binary>> -> extracting;
        _ -> downloading
    end.

%% @doc Build the .container filename for a daemon.
-spec container_filename(binary()) -> binary().
container_filename(DaemonName) ->
    <<DaemonName/binary, ".container">>.

%% @doc Render the Quadlet .container file content.
-spec render_container(binary(), binary()) -> binary().
render_container(DaemonName, OciImage) ->
    BaseImage = strip_tag(OciImage),
    iolist_to_binary([
        "[Unit]\n",
        "Description=Hecate ", DaemonName, " (plugin)\n",
        "After=hecate-daemon.service\n",
        "Wants=hecate-daemon.service\n",
        "\n",
        "[Container]\n",
        "Image=", BaseImage, ":latest\n",
        "ContainerName=", DaemonName, "\n",
        "AutoUpdate=registry\n",
        "Network=host\n",
        "Environment=HOME=%h\n",
        "Volume=%h/.hecate/", DaemonName, ":%h/.hecate/", DaemonName, ":Z\n",
        "Volume=%h/.hecate/hecate-daemon/sockets:%h/.hecate/hecate-daemon/sockets:ro\n",
        "HealthCmd=test -S %h/.hecate/", DaemonName, "/sockets/api.sock\n",
        "HealthInterval=30s\n",
        "HealthRetries=3\n",
        "HealthTimeout=5s\n",
        "HealthStartPeriod=10s\n",
        "\n",
        "[Service]\n",
        "Restart=always\n",
        "RestartSec=5s\n",
        "TimeoutStartSec=60s\n",
        "\n",
        "[Install]\n",
        "WantedBy=default.target\n"
    ]).

%% @doc Extract daemon name from OCI image ref.
-spec extract_daemon_name(binary()) -> binary().
extract_daemon_name(OciImage) ->
    Base = strip_tag(OciImage),
    case binary:matches(Base, <<"/">>) of
        [] -> Base;
        Matches ->
            {Pos, Len} = lists:last(Matches),
            binary:part(Base, Pos + Len, byte_size(Base) - Pos - Len)
    end.

%% @doc Strip the tag from an OCI image reference.
-spec strip_tag(binary()) -> binary().
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
