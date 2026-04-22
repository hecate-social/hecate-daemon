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

-spec post(daemon(), binary(), binary() | map() | iolist()) -> response().
post(Daemon, Path, Body) -> post(Daemon, Path, Body, []).

-spec post(daemon(), binary(), binary() | map() | iolist(),
           [{binary(), binary()}]) -> response().
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

    %% 1. scp the file to the target. Write stderr + stdout to a
    %% tempfile and check its exit status — scp writes a multi-line
    %% SSH pre-connect warning to stderr on this host (post-quantum
    %% KEX advisory) that's not an error; only the exit code
    %% distinguishes success from failure reliably.
    ExitMarker = " ; echo ___EXIT___:$?",
    ScpCmd = lists:flatten(io_lib:format(
        "scp -o ConnectTimeout=5 -o BatchMode=yes ~s ~s:~s 2>&1~s",
        [shell_escape(LocalPath), SSH, RemoteTmp, ExitMarker])),
    case os:cmd(ScpCmd) of
        Out when is_list(Out) ->
            case exit_status_of(Out) of
                0 -> upload_via_curl(SSH, Sock, RemoteTmp,
                                      LogicalPathStr, MimeStr);
                _ -> {error, {scp_failed, Out}}
            end
    end.

exit_status_of(Out) ->
    case re:run(Out, "___EXIT___:(\\d+)", [{capture, [1], list}]) of
        {match, [N]} -> list_to_integer(N);
        nomatch      -> -1
    end.

upload_via_curl(SSH, Sock, RemoteTmp, LogicalPathStr, MimeStr) ->
    %% `2>/dev/null` drops ssh's own stderr (OpenSSH post-quantum KEX
    %% advisory on this host) so it doesn't pollute the response body.
    %% See comment in request/5 above.
    Cmd = lists:flatten(io_lib:format(
        "ssh -o ConnectTimeout=5 -o BatchMode=yes -o LogLevel=ERROR ~s "
        "'curl --silent --max-time 60 --unix-socket ~s "
        "-X POST "
        "--form file=@~s "
        "--form-string path=~s "
        "--form-string mime_type=~s "
        "-w \"\\n%{http_code}\" "
        "http://localhost/api/briefcase/files/upload; "
        "rm -f ~s' "
        "2>/dev/null",
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

    %% Header args use DOUBLE quotes so they nest safely inside the
    %% outer single-quoted ssh command. Earlier single-quoted header
    %% args closed the outer quoting and dropped the Authorization
    %% header entirely, causing 401 on admin endpoints.
    HeaderArgs = lists:map(
        fun({K, V}) ->
            io_lib:format(" -H \"~s: ~s\"", [K, V])
        end, Headers),

    Output = case Body of
        undefined ->
            run_ssh_curl(SSH, Sock, Method, HeaderArgs, PathStr, "");
        _ ->
            BodyBin = iolist_to_binary(Body),
            run_ssh_curl_with_body(SSH, Sock, Method, HeaderArgs,
                                    PathStr, BodyBin)
    end,
    parse_response(Output).

%% @private No body: curl reads nothing from stdin.
run_ssh_curl(SSH, Sock, Method, HeaderArgs, PathStr, ExtraArgs) ->
    %% `2>/dev/null` drops ssh's own stderr (e.g. the OpenSSH
    %% "post-quantum KEX" advisory printed on this host) which would
    %% otherwise get interleaved with curl's stdout and break the
    %% status/body parser.
    Cmd = io_lib:format(
        "ssh -o ConnectTimeout=5 -o BatchMode=yes -o LogLevel=ERROR ~s "
        "'curl --silent --max-time 30 --unix-socket ~s "
        "-X ~s ~s~s -w \"\\n%{http_code}\" http://localhost~s' "
        "2>/dev/null",
        [SSH, Sock, Method, lists:flatten(HeaderArgs),
         ExtraArgs, PathStr]),
    os:cmd(lists:flatten(Cmd)).

%% @private With body: pipe body bytes into ssh locally; ssh forwards
%% stdin to the remote curl via `--data-binary @-`. When the local
%% `printf` exits, its pipe closes, ssh sees EOF and forwards it to
%% curl, which then completes the request.
%%
%% We use `printf '%s' BODY` rather than `echo` because echo appends
%% a newline and interprets backslashes on some shells.
run_ssh_curl_with_body(SSH, Sock, Method, HeaderArgs, PathStr, BodyBin) ->
    BodyArg = shell_escape(binary_to_list(BodyBin)),
    Cmd = io_lib:format(
        "printf '%s' ~s | "
        "ssh -o ConnectTimeout=5 -o BatchMode=yes -o LogLevel=ERROR ~s "
        "'curl --silent --max-time 30 --unix-socket ~s "
        "-X ~s ~s --data-binary @- "
        "-w \"\\n%{http_code}\" http://localhost~s' "
        "2>/dev/null",
        [BodyArg, SSH, Sock, Method, lists:flatten(HeaderArgs), PathStr]),
    os:cmd(lists:flatten(Cmd)).

with_json_header(Headers) ->
    [{<<"Content-Type">>, <<"application/json">>} | Headers].

encode_body(undefined)               -> <<>>;
encode_body(Bin) when is_binary(Bin) -> Bin;
encode_body(Map) when is_map(Map)    -> iolist_to_binary(json:encode(Map));
%% `json:encode/1` returns iodata, not a binary, so callers that
%% pre-encode (e.g. to reuse a body across calls) also land here.
encode_body(IoList) when is_list(IoList) -> iolist_to_binary(IoList).

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
