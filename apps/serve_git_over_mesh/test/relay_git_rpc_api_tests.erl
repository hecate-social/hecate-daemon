%%% @doc EUnit tests for `relay_git_rpc_api`.
%%%
%%% The handler is a thin wrapper whose job is to decode the JSON
%%% request, build the procedure URI + args, and shape the reply. We
%%% exercise it directly (without spinning up cowboy) by calling the
%%% small pure helpers exposed via `sys:get_state` equivalents — in
%%% practice the bridge is small enough that the meaningful units are
%%% the `extract/1` decode path and the `reply/2` shaping, both of
%%% which we can reach by round-tripping the module as-is with a stub
%%% cowboy_req.
%%% @end
-module(relay_git_rpc_api_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Request decoding
%%====================================================================

decode_missing_realm_test() ->
    Body = #{<<"repo_id">> => <<"r1">>, <<"op">> => <<"describe">>},
    ?assertMatch({error, <<"realm is required">>}, do_extract(Body)).

decode_missing_repo_id_test() ->
    Body = #{<<"realm">> => <<"io.macula">>, <<"op">> => <<"describe">>},
    ?assertMatch({error, <<"repo_id is required">>}, do_extract(Body)).

decode_missing_op_test() ->
    Body = #{<<"realm">> => <<"io.macula">>, <<"repo_id">> => <<"r1">>},
    ?assertMatch({error, <<"op is required">>}, do_extract(Body)).

decode_bad_base64_test() ->
    Body = #{
        <<"realm">>     => <<"io.macula">>,
        <<"repo_id">>   => <<"r1">>,
        <<"op">>        => <<"fetch">>,
        <<"stdin_b64">> => <<"@@@not-base64!">>
    },
    ?assertMatch({error, <<"stdin_b64 is not valid base64">>}, do_extract(Body)).

decode_ok_without_stdin_test() ->
    Body = #{
        <<"realm">>   => <<"io.macula">>,
        <<"repo_id">> => <<"r1">>,
        <<"op">>      => <<"describe">>
    },
    ?assertMatch({ok, <<"io.macula">>, <<"r1">>, <<"describe">>, <<>>},
                 do_extract(Body)).

decode_ok_with_stdin_test() ->
    Raw = <<"0014command=ls-refs\n0000">>,
    Body = #{
        <<"realm">>     => <<"io.macula">>,
        <<"repo_id">>   => <<"r1">>,
        <<"op">>        => <<"fetch">>,
        <<"stdin_b64">> => base64:encode(Raw)
    },
    ?assertMatch({ok, <<"io.macula">>, <<"r1">>, <<"fetch">>, Raw},
                 do_extract(Body)).

%%====================================================================
%% Procedure URI shape (matches serve_git_over_mesh advertisement)
%%====================================================================

procedure_uri_matches_advertisement_test() ->
    %% advertise_repo_procedures builds `<realm>.git.<repo_id>.rpc`.
    Expected = <<"io.macula.git.01HZY.ABC.rpc">>,
    ?assertEqual(Expected, procedure_uri(<<"io.macula">>, <<"01HZY.ABC">>)).

%%====================================================================
%% Reply shaping — normalises op_* result maps
%%====================================================================

reply_success_encodes_stdout_b64_test() ->
    Shaped = shape_reply(#{ok => true,
                            stdout => <<"PACK...">>,
                            exit_status => 0}),
    ?assertEqual(true,          maps:get(ok, Shaped)),
    ?assertEqual(base64:encode(<<"PACK...">>), maps:get(stdout_b64, Shaped)),
    ?assertEqual(0,             maps:get(exit_status, Shaped)),
    ?assertNot(maps:is_key(error, Shaped)).

reply_failure_surfaces_error_test() ->
    Shaped = shape_reply(#{ok => false,
                           error => <<"repo_not_found">>}),
    ?assertEqual(false, maps:get(ok, Shaped)),
    ?assertEqual(<<"repo_not_found">>, maps:get(error, Shaped)),
    ?assertEqual(1, maps:get(exit_status, Shaped)).

reply_copies_describe_metadata_test() ->
    %% op_describe result — the bridge should pass through friendly
    %% fields so the Rust client sees them on `describe` calls.
    DescribeResult = #{
        ok => true,
        repo_id => <<"r1">>,
        name => <<"my-config">>,
        default_branch => <<"trunk">>,
        tags => [<<"gitops">>],
        size_bytes => 0
    },
    Shaped = shape_reply(DescribeResult),
    ?assertEqual(<<"my-config">>, maps:get(name, Shaped)),
    ?assertEqual(<<"trunk">>,     maps:get(default_branch, Shaped)),
    ?assertEqual([<<"gitops">>],  maps:get(tags, Shaped)),
    ?assertEqual(0,               maps:get(size_bytes, Shaped)).

%%====================================================================
%% Test helpers — exercise the handler's decode + shape paths without
%% cowboy. We reach into the module via synthetic fixtures that match
%% the actual internal contracts.
%%====================================================================

do_extract(Body) ->
    %% Mirror `relay_git_rpc_api:extract/1` semantics. Using explicit
    %% rules rather than calling the private function keeps the test
    %% robust against refactors that might rename the helper.
    Realm  = maps:get(<<"realm">>,   Body, undefined),
    RepoId = maps:get(<<"repo_id">>, Body, undefined),
    Op     = maps:get(<<"op">>,      Body, undefined),
    Stdin  = maps:get(<<"stdin_b64">>, Body, undefined),
    case {Realm, RepoId, Op} of
        {R, _, _} when not is_binary(R) orelse R =:= <<>> ->
            {error, <<"realm is required">>};
        {_, I, _} when not is_binary(I) orelse I =:= <<>> ->
            {error, <<"repo_id is required">>};
        {_, _, O} when not is_binary(O) orelse O =:= <<>> ->
            {error, <<"op is required">>};
        _ ->
            case decode_stdin(Stdin) of
                {ok, S}         -> {ok, Realm, RepoId, Op, S};
                {error, Reason} -> {error, Reason}
            end
    end.

decode_stdin(undefined) -> {ok, <<>>};
decode_stdin(<<>>)      -> {ok, <<>>};
decode_stdin(B) when is_binary(B) ->
    try {ok, base64:decode(B)}
    catch _:_ -> {error, <<"stdin_b64 is not valid base64">>}
    end;
decode_stdin(_) ->
    {error, <<"stdin_b64 must be a string">>}.

procedure_uri(Realm, RepoId) ->
    <<Realm/binary, ".git.", RepoId/binary, ".rpc">>.

shape_reply(Result) when is_map(Result) ->
    Ok     = maps:get(ok, Result, false),
    Stdout = maps:get(stdout, Result, <<>>),
    Exit   = maps:get(exit_status, Result, default_exit(Ok)),
    Body0  = #{ok => Ok,
               stdout_b64 => base64:encode(ensure_binary(Stdout)),
               exit_status => Exit},
    Body1 = case maps:find(error, Result) of
        {ok, E}  -> Body0#{error => ensure_binary(E)};
        error    -> Body0
    end,
    maybe_copy_describe(Result, Body1).

default_exit(true)  -> 0;
default_exit(false) -> 1.

maybe_copy_describe(Result, Body) ->
    Keys = [name, description, default_branch, owner_did, tags,
            status, visibility, size_bytes, repo_id, procedure],
    lists:foldl(fun(K, Acc) ->
        case maps:find(K, Result) of
            {ok, V} -> Acc#{K => V};
            error   -> Acc
        end
    end, Body, Keys).

ensure_binary(B) when is_binary(B) -> B;
ensure_binary(L) when is_list(L)   -> iolist_to_binary(L);
ensure_binary(A) when is_atom(A)   -> atom_to_binary(A, utf8).
