%%% @doc Streaming sibling of git_over_mesh_procedure.
%%%
%%% Phase 4 pilot 3 of PLAN_MACULA_STREAMING.md. Server-stream RPC
%%% that runs `git upload-pack --stateless-rpc` and pipes the pack
%%% bytes back to the caller as raw STREAM_DATA chunks. Replaces the
%%% legacy whole-pack reply for clone/fetch — repos beyond a few MB
%%% become workable.
%%%
%%% Procedure: <Realm>.git.<RepoId>.fetch_stream
%%%
%%% Open Args:
%%%   #{ <<"stdin">> => binary(),                 %% client's pkt-line v2 fetch request
%%%      <<"service_args">> => [string()] | undefined }
%%%
%%% Stream chunks: raw bytes from git upload-pack stdout. EOF on
%%% process exit. STREAM_ERROR on bad request, missing repo, or
%%% non-zero git exit status.
%%%
%%% PUSH (client-stream) is intentionally NOT shipped in this commit.
%%% receive-pack needs live stdin chunking from the caller, which
%%% Erlang's open_port can't half-close. Add when we adopt erlexec or
%%% a custom port-program with stdin half-close support.
-module(git_over_mesh_stream_procedure).

-export([handle/3]).

%% @doc Stream handler dispatcher. Args carries `op` so the same
%% `_stream.rpc` procedure could fan out to multiple verbs in the
%% future; today only `fetch` is wired.
-spec handle(binary(), pid(), term()) -> ok.
handle(RepoId, Stream, Args) ->
    Op = op(Args),
    do_op(Op, RepoId, Stream, Args).

do_op(<<"fetch">>, RepoId, Stream, Args) ->
    op_fetch_stream:run(RepoId, Stream, Args);
do_op(_, _RepoId, Stream, _Args) ->
    macula:abort(Stream, <<"unsupported_op">>,
                 <<"only 'fetch' is supported in stream mode (push pending)">>),
    ok.

op(#{<<"op">> := Op}) when is_binary(Op) -> Op;
op(#{op := Op}) when is_atom(Op) -> atom_to_binary(Op, utf8);
op(#{op := Op}) when is_binary(Op) -> Op;
op(_) -> <<"fetch">>.   %% default — server-stream against this MRI is fetch
