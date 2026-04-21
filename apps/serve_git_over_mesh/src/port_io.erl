%%% @doc Run an external binary with a one-shot stdin blob, collect stdout.
%%%
%%% Used by `op_fetch` / `op_push` to invoke `git upload-pack` /
%%% `git receive-pack` in `--stateless-rpc` mode. Stateless-rpc reads
%%% the entire client request from stdin, processes it, writes the
%%% response on stdout, and exits.
%%%
%%% ## Why not use open_port/spawn_executable directly?
%%%
%%% Erlang's port interface does not expose a way to half-close stdin
%%% on a spawned child. Git's `--stateless-rpc` mode only flushes its
%%% response once it observes EOF on stdin. Rather than bolt on an
%%% `erlexec` dependency for this walking skeleton, we write the
%%% request to a temporary file and invoke the binary via `sh -c`
%%% with input redirection. That guarantees EOF once the binary has
%%% read the file.
%%%
%%% This is the Phase 2 constraint: whole-request, whole-response.
%%% When macula ships a streaming RPC primitive (Phase 2.1), this
%%% helper is superseded by a chunked variant.
%%% @end
-module(port_io).

-export([run/3, run/4]).

-define(DEFAULT_TIMEOUT_MS, 30000).

-type result() :: #{ok         := boolean(),
                    stdout     := binary(),
                    exit_status := integer()} |
                  {error, term()}.

-spec run(file:filename(), [string()], binary()) -> result().
run(Exe, Args, StdinBin) ->
    run(Exe, Args, StdinBin, ?DEFAULT_TIMEOUT_MS).

-spec run(file:filename(), [string()], binary(), pos_integer()) -> result().
run(Exe, Args, StdinBin, TimeoutMs)
  when is_list(Exe), is_list(Args), is_binary(StdinBin),
       is_integer(TimeoutMs), TimeoutMs > 0 ->
    %% Write stdin to a tempfile and redirect via sh -c so git sees EOF.
    TmpIn  = make_temp_path("gom-stdin"),
    case file:write_file(TmpIn, StdinBin) of
        ok ->
            try
                ShCmd = build_shell_command(Exe, Args, TmpIn),
                run_sh(ShCmd, TimeoutMs)
            after
                _ = file:delete(TmpIn)
            end;
        {error, _} = Err ->
            Err
    end.

%%====================================================================
%% Internal
%%====================================================================

run_sh(ShCmd, TimeoutMs) ->
    Opts = [binary, exit_status, stderr_to_stdout, stream, {cd, "/tmp"}],
    Port = erlang:open_port({spawn, ShCmd}, Opts),
    collect(Port, <<>>, TimeoutMs).

collect(Port, Acc, TimeoutMs) ->
    receive
        {Port, {data, Chunk}} ->
            collect(Port, <<Acc/binary, Chunk/binary>>, TimeoutMs);
        {Port, {exit_status, Status}} ->
            #{ok          => Status =:= 0,
              stdout      => Acc,
              exit_status => Status}
    after TimeoutMs ->
        catch erlang:port_close(Port),
        {error, {timeout, TimeoutMs}}
    end.

build_shell_command(Exe, Args, TmpIn) ->
    %% sh-quote every fragment — repo paths may contain dashes, dots, slashes
    %% but we keep them tame and still quote defensively.
    Quoted = [sh_quote(Exe) | [sh_quote(A) || A <- Args]],
    lists:flatten(string:join(Quoted, " ")
                  ++ " < " ++ sh_quote(TmpIn)).

sh_quote(Str) when is_list(Str) ->
    "'" ++ lists:flatmap(fun($') -> "'\\''"; (C) -> [C] end, Str) ++ "'".

make_temp_path(Prefix) ->
    Rand = integer_to_list(erlang:unique_integer([positive])),
    Pid  = os:getpid(),
    filename:join("/tmp", Prefix ++ "-" ++ Pid ++ "-" ++ Rand).
