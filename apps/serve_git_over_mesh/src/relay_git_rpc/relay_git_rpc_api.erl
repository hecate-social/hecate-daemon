%%% @doc Cowboy handler — bridges `git-remote-mesh`'s local HTTP
%%% requests into a Macula mesh RPC call.
%%%
%%% This is the daemon-side counterpart of the `git-remote-mesh` Rust
%%% binary. The binary speaks the git remote-helper protocol on stdio
%%% and POSTs the underlying `git upload-pack --stateless-rpc` / push
%%% payloads to us at `/api/git/rpc`. We turn each request into a
%%% `macula:call/4` against the per-repo procedure MRI advertised by
%%% `serve_git_over_mesh:advertise_repo_procedures`
%%% (`<Realm>.git.<RepoId>.rpc`).
%%%
%%% When the target repo is hosted on the local node, macula's RPC
%%% routing takes the in-process shortcut — the call never leaves the
%%% BEAM. Cross-node calls hop through the relay fleet.
%%%
%%% Wire format:
%%% ```
%%% POST /api/git/rpc
%%% { "realm":     "io.macula",
%%%   "repo_id":   "01HZY...ABCD",
%%%   "op":        "describe" | "fetch" | "push",
%%%   "stdin_b64": "<base64 of the git stateless-rpc payload>" }
%%%
%%% 200 OK
%%% { "ok": true,
%%%   "stdout_b64":  "<base64 of git's stdout>",
%%%   "exit_status": 0 }
%%%
%%% 200 OK (op-level failure)
%%% { "ok": false, "error": "repo_not_found", "exit_status": 1 }
%%% ```
%%%
%%% HTTP 400 is used only for request-shape errors (bad JSON, missing
%%% fields). Application-level failures stay inside a 200 body with
%%% `ok: false` so the Rust client can always deserialize.
%%% @end
-module(relay_git_rpc_api).

-export([init/2, routes/0]).

-define(CALL_TIMEOUT_MS, 60000).

routes() -> [{"/api/git/rpc", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _          -> hecate_api_utils:method_not_allowed(Req0)
    end.

%%====================================================================
%% Internal
%%====================================================================

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Body, Req1} when is_map(Body) ->
            case extract(Body) of
                {ok, Realm, RepoId, Op, Stdin} ->
                    reply(dispatch(Realm, RepoId, Op, Stdin), Req1);
                {error, Reason} ->
                    hecate_api_utils:bad_request(Reason, Req1)
            end;
        {ok, _NotAMap, Req1} ->
            hecate_api_utils:bad_request(<<"JSON body must be an object">>, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

-spec extract(map()) ->
    {ok, binary(), binary(), binary(), binary()} | {error, binary()}.
extract(Body) ->
    Realm   = field(<<"realm">>,   Body),
    RepoId  = field(<<"repo_id">>, Body),
    Op      = field(<<"op">>,      Body),
    StdinB  = field(<<"stdin_b64">>, Body),
    case {Realm, RepoId, Op} of
        {R, _, _} when not is_binary(R) orelse R =:= <<>> ->
            {error, <<"realm is required">>};
        {_, I, _} when not is_binary(I) orelse I =:= <<>> ->
            {error, <<"repo_id is required">>};
        {_, _, O} when not is_binary(O) orelse O =:= <<>> ->
            {error, <<"op is required">>};
        _ ->
            case decode_stdin(StdinB) of
                {ok, Stdin} -> {ok, Realm, RepoId, Op, Stdin};
                {error, Reason} -> {error, Reason}
            end
    end.

field(Key, Map) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error   -> undefined
    end.

decode_stdin(undefined) -> {ok, <<>>};
decode_stdin(<<>>)      -> {ok, <<>>};
decode_stdin(B) when is_binary(B) ->
    try {ok, base64:decode(B)}
    catch _:_ -> {error, <<"stdin_b64 is not valid base64">>}
    end;
decode_stdin(_) ->
    {error, <<"stdin_b64 must be a string">>}.

%%====================================================================
%% Dispatch — mesh first, informative error if mesh is dormant.
%%====================================================================

dispatch(Realm, RepoId, Op, Stdin) ->
    Procedure = <<Realm/binary, ".git.", RepoId/binary, ".rpc">>,
    Args = #{<<"op">> => Op, <<"stdin">> => Stdin},
    case hecate_mesh_client:is_activated() of
        true ->
            call_via_mesh(Procedure, Args);
        false ->
            #{ok => false,
              error => <<"mesh_not_activated">>,
              procedure => Procedure,
              hint => <<"POST /api/mesh/activate first">>}
    end.

call_via_mesh(Procedure, Args) ->
    %% Client is a macula_multi_relay pid; dispatch via multi_relay
    %% (macula:call routes via macula_mesh_client, which does not handle
    %% multi_relay pids). See hecate_mesh_client.erl:279.
    case hecate_mesh_client:get_client() of
        {ok, Client} when is_pid(Client) ->
            try macula_multi_relay:call(Client, Procedure, Args, ?CALL_TIMEOUT_MS) of
                {ok, Result} when is_map(Result) ->
                    Result;
                {ok, Other} ->
                    #{ok => false,
                      error => <<"unexpected_reply_shape">>,
                      reply => io_fmt(Other)};
                {error, Reason} ->
                    #{ok => false, error => fmt_error(Reason), procedure => Procedure}
            catch
                Class:Ex ->
                    #{ok => false,
                      error => <<"rpc_exception">>,
                      class => atom_to_binary(Class),
                      detail => io_fmt(Ex)}
            end;
        _ ->
            #{ok => false, error => <<"mesh_client_unavailable">>}
    end.

%%====================================================================
%% Reply shaping — normalise op_* result maps to the bridge contract.
%%====================================================================

reply(Result, Req) when is_map(Result) ->
    Ok        = maps:get(ok, Result, maps:get(<<"ok">>, Result, false)),
    Stdout    = maps:get(stdout, Result, maps:get(<<"stdout">>, Result, <<>>)),
    Exit      = maps:get(exit_status, Result, maps:get(<<"exit_status">>, Result, default_exit(Ok))),
    Body0     = #{ok => Ok,
                  stdout_b64 => base64:encode(ensure_binary(Stdout)),
                  exit_status => Exit},
    Body1 = case maps:get(error, Result, maps:get(<<"error">>, Result, undefined)) of
        undefined -> Body0;
        E         -> Body0#{error => ensure_binary(E)}
    end,
    %% Preserve describe metadata when present — gives the Rust client
    %% a richer reply for the `describe` op without forcing it to do
    %% another round-trip.
    Body2 = maybe_copy_describe_fields(Result, Body1),
    hecate_api_utils:json_ok(Body2, Req).

default_exit(true)  -> 0;
default_exit(false) -> 1;
default_exit(_)     -> 0.

maybe_copy_describe_fields(Result, Body) ->
    Keys = [name, description, default_branch, owner_did, tags,
            status, visibility, size_bytes, repo_id, procedure],
    lists:foldl(fun(K, Acc) ->
        case maps:find(K, Result) of
            {ok, V} -> Acc#{K => V};
            error ->
                BK = atom_to_binary(K, utf8),
                case maps:find(BK, Result) of
                    {ok, V} -> Acc#{K => V};
                    error   -> Acc
                end
        end
    end, Body, Keys).

%%====================================================================
%% Helpers
%%====================================================================

ensure_binary(B) when is_binary(B) -> B;
ensure_binary(L) when is_list(L)   -> iolist_to_binary(L);
ensure_binary(A) when is_atom(A)   -> atom_to_binary(A, utf8);
ensure_binary(Other) -> io_fmt(Other).

io_fmt(T) -> iolist_to_binary(io_lib:format("~p", [T])).

fmt_error(E) when is_binary(E) -> E;
fmt_error(E) when is_atom(E)   -> atom_to_binary(E, utf8);
fmt_error(E)                   -> io_fmt(E).
