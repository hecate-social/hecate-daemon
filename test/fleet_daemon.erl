%%% @doc Curl-via-SSH wrapper for talking to a fleet daemon's local
%%% Unix socket.
%%%
%%% Each call shells out via `os:cmd("ssh ... 'curl --unix-socket
%%% .../api.sock ...'")`. Returns `{Status, Body}` parsed from curl's
%%% `-w '\n%{http_code}'` trailer. Slow (250-500ms per call) but
%%% reliable + needs zero infrastructure beyond an SSH key already on
%%% the operator's laptop.
%%%
%%% Future optimisation: maintain one persistent `ssh:connect/4`
%%% session per node and pump curls through it via
%%% `ssh_connection:exec/3`. Keeps the same external API.
%%% @end
-module(fleet_daemon).

-export([get/2, get/3, post/3, post/4, delete/2, delete/3, upload/3, upload/4]).

-type daemon() :: map().
-type response() :: {pos_integer(), binary()} | {error, term()}.

%%====================================================================
%% API
%%====================================================================

-spec get(daemon(), binary()) -> response().
get(Daemon, Path) -> get(Daemon, Path, []).

-spec get(daemon(), binary(), [{binary(), binary()}]) -> response().
get(Daemon, Path, Headers) ->
    request(Daemon, "GET", Path, Headers, undefined).

-spec post(daemon(), binary(), binary() | map()) -> response().
post(Daemon, Path, Body) -> post(Daemon, Path, Body, []).

-spec post(daemon(), binary(), binary() | map(), [{binary(), binary()}]) ->
    response().
post(Daemon, Path, Body, Headers) ->
    request(Daemon, "POST", Path, with_json_header(Headers), encode_body(Body)).

-spec delete(daemon(), binary()) -> response().
delete(Daemon, Path) -> delete(Daemon, Path, []).

delete(Daemon, Path, Headers) ->
    request(Daemon, "DELETE", Path, Headers, undefined).

%% @doc Upload a file via multipart POST. `LocalPath` is read on the
%% test runner machine; `LogicalPath` is what the daemon records as
%% the file's logical name.
%%
%% Implementation: scp the file to /tmp on the SSH target (so curl
%% --form @/tmp/... can read it), invoke curl --unix-socket --form,
%% then `rm` the tempfile in the same SSH session. Three round-trips
%% per upload — slow, but reliable, and tests aren't latency-sensitive.
-spec upload(daemon(), file:filename(), binary()) -> response().
upload(Daemon, LocalPath, LogicalPath) ->
    upload(Daemon, LocalPath, LogicalPath, <<"application/octet-stream">>).

-spec upload(daemon(), file:filename(), binary(), binary()) -> response().
upload(Daemon, LocalPath, LogicalPath, MimeType) ->
    SSH = binary_to_list(maps:get(ssh, Daemon)),
    Sock = binary_to_list(maps:get(socket, Daemon)),
    RemoteTmp = "/tmp/fleet_upload_"
                ++ integer_to_list(erlang:unique_integer([positive])),
    LogicalPathStr = binary_to_list(LogicalPath),
    MimeStr = binary_to_list(MimeType),

    %% 1. scp the file to the target.
    ScpCmd = lists:flatten(io_lib:format(
        "scp -o ConnectTimeout=5 -o BatchMode=yes ~s ~s:~s 2>&1",
        [shell_escape(LocalPath), SSH, RemoteTmp])),
    case os:cmd(ScpCmd) of
        Out when is_list(Out) ->
            %% scp returns empty on success, error message on failure.
            case string:trim(Out) of
                ""    -> upload_via_curl(SSH, Sock, RemoteTmp,
                                          LogicalPathStr, MimeStr);
                Error -> {error, {scp_failed, Error}}
            end
    end.

upload_via_curl(SSH, Sock, RemoteTmp, LogicalPathStr, MimeStr) ->
    Cmd = lists:flatten(io_lib:format(
        "ssh -o ConnectTimeout=5 -o BatchMode=yes ~s "
        "'curl --silent --max-time 60 --unix-socket ~s "
        "-X POST "
        "--form file=@~s "
        "--form-string path=~s "
        "--form-string mime_type=~s "
        "-w \"\\n%{http_code}\" "
        "http://localhost/api/briefcase/files/upload; "
        "rm -f ~s'",
        [SSH, Sock, RemoteTmp, LogicalPathStr, MimeStr, RemoteTmp])),
    parse_response(os:cmd(Cmd)).

shell_escape(S) when is_list(S) ->
    %% Wrap in single quotes; escape any embedded single quotes by
    %% closing-quoting-reopening.
    "'" ++ string:replace(S, "'", "'\"'\"'", all) ++ "'";
shell_escape(S) when is_binary(S) ->
    shell_escape(binary_to_list(S)).

%%====================================================================
%% Internal
%%====================================================================

request(Daemon, Method, Path, Headers, Body) ->
    SSH = binary_to_list(maps:get(ssh, Daemon)),
    Sock = binary_to_list(maps:get(socket, Daemon)),
    PathStr = binary_to_list(Path),

    HeaderArgs = lists:map(
        fun({K, V}) ->
            io_lib:format(" -H '~s: ~s'", [K, V])
        end, Headers),

    DataArg = case Body of
        undefined -> "";
        _Bin      -> " --data-binary @-"
    end,

    Cmd = io_lib:format(
        "ssh -o ConnectTimeout=5 -o BatchMode=yes ~s "
        "'curl --silent --max-time 30 --unix-socket ~s "
        "-X ~s ~s~s -w \"\\n%{http_code}\" http://localhost~s'",
        [SSH, Sock, Method, lists:flatten(HeaderArgs),
         DataArg, PathStr]),
    Cmd2 = lists:flatten(Cmd),

    Output = case Body of
        undefined -> os:cmd(Cmd2);
        Bin2      -> shell_with_stdin(Cmd2, Bin2)
    end,
    parse_response(Output).

with_json_header(Headers) ->
    [{<<"Content-Type">>, <<"application/json">>} | Headers].

encode_body(undefined)             -> <<>>;
encode_body(Bin) when is_binary(Bin) -> Bin;
encode_body(Map) when is_map(Map)  -> json:encode(Map).

shell_with_stdin(Cmd, Stdin) ->
    Port = open_port({spawn, Cmd},
                     [stream, in, out, exit_status, binary]),
    port_command(Port, Stdin),
    port_close_input(Port),
    collect_output(Port, <<>>).

%% @private Some Erlang versions expose this as `port_close/1` only
%% closing both halves; on others a separate close is required. Wrap
%% the cross-version differences here.
port_close_input(Port) ->
    %% Easiest portable way: send EOF by sending an empty packet.
    %% In practice this works on all OTP versions we run.
    try port_command(Port, <<>>) catch _:_ -> ok end,
    ok.

collect_output(Port, Acc) ->
    receive
        {Port, {data, Data}} -> collect_output(Port, <<Acc/binary, Data/binary>>);
        {Port, {exit_status, _}} -> binary_to_list(Acc)
    after 60000 ->
        catch port_close(Port),
        {error, timeout}
    end.

%% Curl's `-w "\n%{http_code}"` puts the status code on the last line.
parse_response(Output) when is_list(Output) ->
    case lists:reverse(string:split(Output, "\n", all)) of
        [LastLine | RestRev] ->
            case parse_status(string:trim(LastLine)) of
                {ok, Status} ->
                    Body = string:join(lists:reverse(RestRev), "\n"),
                    {Status, list_to_binary(string:trim(Body, trailing, "\n"))};
                error ->
                    {error, {bad_curl_output, Output}}
            end;
        _ -> {error, {bad_curl_output, Output}}
    end;
parse_response(Other) -> {error, {bad_response, Other}}.

parse_status(Str) ->
    try {ok, list_to_integer(Str)}
    catch _:_ -> error
    end.
