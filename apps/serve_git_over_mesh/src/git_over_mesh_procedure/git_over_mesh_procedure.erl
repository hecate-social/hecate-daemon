%%% @doc Dispatch module for the per-repo mesh RPC procedure.
%%%
%%% Procedures are advertised as `{Realm}.git.{RepoId}.rpc` and
%%% multiplex three operations via the `op` field on `Args`:
%%%
%%%   - `<<"describe">>` — metadata lookup (no git invocation)
%%%   - `<<"fetch">>`    — `git upload-pack --stateless-rpc`
%%%   - `<<"push">>`     — `git receive-pack --stateless-rpc`
%%%
%%% ## Phase 2 constraint — no streaming yet
%%%
%%% Macula SDK v1.4.30 has no streaming RPC primitive
%%% (`macula:call/3,4`, no `call_stream`). This dispatcher therefore
%%% returns whole-pack responses in a single reply. That is adequate
%%% for the current Phase 2 targets — config repos, persona repos,
%%% Martha — all small. A chunked variant replaces this once macula
%%% ships the primitive (Phase 2.1).
%%% @end
-module(git_over_mesh_procedure).

-export([handle/2]).

-spec handle(binary(), map()) -> map().
handle(RepoId, Args) when is_binary(RepoId), is_map(Args) ->
    Op = op(Args),
    dispatch(Op, RepoId, Args).

%%====================================================================
%% Internal
%%====================================================================

dispatch(<<"describe">>, RepoId, _Args) -> op_describe:run(RepoId);
dispatch(<<"fetch">>,    RepoId,  Args) -> op_fetch:run(RepoId, Args);
dispatch(<<"push">>,     RepoId,  Args) -> op_push:run(RepoId, Args);
dispatch(Unknown,       _RepoId, _Args) ->
    #{ok => false, error => <<"unknown_op">>, op => to_binary(Unknown)}.

op(Args) ->
    case maps:find(op, Args) of
        {ok, V} -> to_binary(V);
        error ->
            case maps:find(<<"op">>, Args) of
                {ok, V} -> to_binary(V);
                error   -> <<"describe">>
            end
    end.

to_binary(B) when is_binary(B) -> B;
to_binary(L) when is_list(L)   -> list_to_binary(L);
to_binary(A) when is_atom(A)   -> atom_to_binary(A, utf8).
