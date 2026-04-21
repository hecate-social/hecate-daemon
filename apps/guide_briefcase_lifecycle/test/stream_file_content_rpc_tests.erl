%%% @doc EUnit for stream_file_content_rpc.
%%%
%%% Tests the briefcase get_chunk_stream handler against
%%% macula_stream_local (Phase 1 dispatch path) so we exercise the
%%% SDK + the file-streaming logic without needing a live mesh.
%%% A temp HECATE_HOME directory hosts the briefcase content store
%%% so tests don't pollute the dev environment.
-module(stream_file_content_rpc_tests).

-include_lib("eunit/include/eunit.hrl").

-define(PROC, <<"test.briefcase.get_chunk_stream">>).
%% Use a 32-hex-char file_id (matches BLAKE3 truncation pattern).
-define(FILE_ID, <<"deadbeef00112233445566778899aabb">>).

setup() ->
    {ok, _} = application:ensure_all_started(macula),
    TmpDir = filename:join(["/tmp", "briefcase_stream_test_" ++
                            integer_to_list(erlang:unique_integer([positive]))]),
    ok = filelib:ensure_path(TmpDir),
    OldHome = os:getenv("HECATE_HOME"),
    os:putenv("HECATE_HOME", TmpDir),
    [macula:unadvertise_stream(P)
     || {P, _} <- macula_stream_local:list_advertised()],
    %% Advertise our test procedure with the real handler so we test
    %% the production code path end-to-end.
    ok = macula:advertise_stream(?PROC, server_stream,
            fun(Stream, Args) ->
                stream_file_content_rpc:handle(Stream, Args)
            end),
    {TmpDir, OldHome}.

teardown({TmpDir, OldHome}) ->
    [macula:unadvertise_stream(P)
     || {P, _} <- macula_stream_local:list_advertised()],
    case OldHome of
        false -> os:unsetenv("HECATE_HOME");
        _ -> os:putenv("HECATE_HOME", OldHome)
    end,
    _ = file:del_dir_r(TmpDir),
    ok.

with_setup(Tests) ->
    {setup, fun setup/0, fun teardown/1, Tests}.

%%% ===================================================================
%%% Tests
%%% ===================================================================

stream_small_file_test_() ->
    with_setup([
        {"single chunk file streams in one chunk then eof",
         fun() ->
             ok = briefcase_content_store:put(?FILE_ID, <<"hello world">>),
             {ok, S} = macula:call_stream(?PROC,
                 #{<<"file_id">> => ?FILE_ID}),
             ?assertEqual({chunk, <<"hello world">>},
                          macula:recv(S, 1000)),
             ?assertEqual(eof, macula:recv(S, 1000))
         end}
    ]).

stream_multi_chunk_file_test_() ->
    with_setup([
        {"file > 64KB streams as multiple chunks",
         fun() ->
             %% 200 KB of repeating bytes — 4 chunks of 64 KB + remainder
             Bytes = binary:copy(<<"x">>, 200 * 1024),
             ok = briefcase_content_store:put(?FILE_ID, Bytes),
             {ok, S} = macula:call_stream(?PROC,
                 #{<<"file_id">> => ?FILE_ID}),
             Reassembled = drain(S, <<>>, 0),
             ?assertEqual(Bytes, Reassembled)
         end}
    ]).

missing_file_test_() ->
    with_setup([
        {"unknown file_id aborts with not_available",
         fun() ->
             {ok, S} = macula:call_stream(?PROC,
                 #{<<"file_id">> => <<"nonexistent000000000000000000000">>}),
             ?assertMatch({error, {<<"not_available">>, _}},
                          macula:recv(S, 1000))
         end}
    ]).

bad_request_test_() ->
    with_setup([
        {"missing file_id field aborts with bad_request",
         fun() ->
             {ok, S} = macula:call_stream(?PROC, #{}),
             ?assertMatch({error, {<<"bad_request">>, _}},
                          macula:recv(S, 1000))
         end},
        {"empty file_id aborts with bad_request",
         fun() ->
             {ok, S} = macula:call_stream(?PROC,
                 #{<<"file_id">> => <<>>}),
             ?assertMatch({error, {<<"bad_request">>, _}},
                          macula:recv(S, 1000))
         end}
    ]).

%%% ===================================================================
%%% Helpers
%%% ===================================================================

drain(Stream, Acc, Chunks) ->
    case macula:recv(Stream, 2000) of
        {chunk, Bin} -> drain(Stream, <<Acc/binary, Bin/binary>>, Chunks + 1);
        eof ->
            ?assert(Chunks >= 4),  %% 200 KB / 64 KB ≥ 4 chunks
            Acc;
        Other -> erlang:error({unexpected, Other})
    end.
