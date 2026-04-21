%%% @doc Run an external binary with a one-shot stdin blob, stream
%%% stdout chunks via a callback as they arrive.
%%%
%%% Streaming sibling of port_io:run/3,4. Same EOF trick (write
%%% stdin to a tmpfile and invoke via sh -c with input redirection),
%%% so this still works with git's --stateless-rpc mode which only
%%% flushes after stdin EOF. The win is on the OUTPUT side: each
%%% chunk delivered by the port is forwarded to the caller's Sink fun
%%% as it arrives, so callers can pipe pack bytes into a macula
%%% stream without buffering the whole response.
%%%
%%% Upgrade path: when we add a half-close-capable Unix port (likely
%%% via erlexec or a custom port-program), client-stream RPC can
%%% feed receive-pack stdin live and this helper graduates to bidi.
-module(port_io_stream).

-export([run/4, run/5]).

-define(DEFAULT_TIMEOUT_MS, 60000).

-type sink() :: fun((binary()) -> ok | {error, term()}).
-type result() :: #{ok := boolean(), exit_status := integer()}
                | {error, term()}.

-spec run(file:filename(), [string()], binary(), sink()) -> result().
run(Exe, Args, StdinBin, Sink) ->
    run(Exe, Args, StdinBin, Sink, ?DEFAULT_TIMEOUT_MS).

-spec run(file:filename(), [string()], binary(), sink(), pos_integer()) ->
        result().
run(Exe, Args, StdinBin, Sink, TimeoutMs)
  when is_list(Exe), is_list(Args), is_binary(StdinBin),
       is_function(Sink, 1), is_integer(TimeoutMs), TimeoutMs > 0 ->
    TmpIn = make_temp_path("gom-stream-stdin"),
    case file:write_file(TmpIn, StdinBin) of
        ok ->
            try
                ShCmd = build_shell_command(Exe, Args, TmpIn),
                run_sh(ShCmd, Sink, TimeoutMs)
            after
                _ = file:delete(TmpIn)
            end;
        {error, _} = Err ->
            Err
    end.

%%====================================================================
%% Internal
%%====================================================================

run_sh(ShCmd, Sink, TimeoutMs) ->
    Opts = [binary, exit_status, stderr_to_stdout, stream, {cd, "/tmp"}],
    Port = erlang:open_port({spawn, ShCmd}, Opts),
    pump(Port, Sink, TimeoutMs).

pump(Port, Sink, TimeoutMs) ->
    receive
        {Port, {data, Chunk}} ->
            handle_sink_result(Sink(Chunk), Port, Sink, TimeoutMs);
        {Port, {exit_status, Status}} ->
            #{ok => Status =:= 0, exit_status => Status}
    after TimeoutMs ->
        catch erlang:port_close(Port),
        {error, {timeout, TimeoutMs}}
    end.

%% @private If the sink returned an error (e.g. the macula stream's
%% peer hung up), close the port early — no point producing more
%% bytes nobody will consume.
handle_sink_result(ok, Port, Sink, TimeoutMs) ->
    pump(Port, Sink, TimeoutMs);
handle_sink_result({error, Reason}, Port, _Sink, _TimeoutMs) ->
    catch erlang:port_close(Port),
    {error, {sink, Reason}}.

build_shell_command(Exe, Args, TmpIn) ->
    Quoted = [sh_quote(Exe) | [sh_quote(A) || A <- Args]],
    lists:flatten(string:join(Quoted, " ") ++ " < " ++ sh_quote(TmpIn)).

sh_quote(Str) when is_list(Str) ->
    "'" ++ lists:flatmap(fun($') -> "'\\''"; (C) -> [C] end, Str) ++ "'".

make_temp_path(Prefix) ->
    Rand = integer_to_list(erlang:unique_integer([positive])),
    Pid  = os:getpid(),
    filename:join("/tmp", Prefix ++ "-" ++ Pid ++ "-" ++ Rand).
