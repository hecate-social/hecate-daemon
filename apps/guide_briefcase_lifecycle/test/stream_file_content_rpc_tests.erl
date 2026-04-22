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
-define(FILES_TABLE, my_issued_files).

%% @private Register a CEK for ?FILE_ID in the my_issued_files ETS so
%% the encrypt-on-serve path can look it up. Returns the plaintext
%% CEK so tests can decrypt what they receive.
seed_cek(FileId) ->
    case ets:info(?FILES_TABLE) of
        undefined -> ets:new(?FILES_TABLE, [public, named_table, set]);
        _         -> ok
    end,
    Cek = crypto:strong_rand_bytes(32),
    {ok, Sealed} = hecate_crypto:encrypt(Cek),
    ets:insert(?FILES_TABLE, {FileId,
                              #{file_id => FileId,
                                origin_cek_sealed => Sealed,
                                realm => <<"io.macula">>,
                                issuer_did => <<"test">>}}),
    Cek.

clear_cek(FileId) ->
    case ets:info(?FILES_TABLE) of
        undefined -> ok;
        _         -> ets:delete(?FILES_TABLE, FileId)
    end.

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
    clear_cek(?FILE_ID),
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
        {"single chunk file streams as one encrypted frame + eof",
         fun() ->
             Cek = seed_cek(?FILE_ID),
             ok = briefcase_content_store:put(?FILE_ID, <<"hello world">>),
             {ok, S} = macula:call_stream(?PROC,
                 #{<<"file_id">> => ?FILE_ID}),
             Plaintext = drain_and_decrypt(S, Cek),
             ?assertEqual(<<"hello world">>, Plaintext)
         end}
    ]).

stream_multi_chunk_file_test_() ->
    with_setup([
        {"file > 64KB streams as multiple encrypted frames",
         fun() ->
             Cek = seed_cek(?FILE_ID),
             %% 200 KB of repeating bytes — 4 chunks of 64 KB + remainder
             Bytes = binary:copy(<<"x">>, 200 * 1024),
             ok = briefcase_content_store:put(?FILE_ID, Bytes),
             {ok, S} = macula:call_stream(?PROC,
                 #{<<"file_id">> => ?FILE_ID}),
             Reassembled = drain_and_decrypt(S, Cek),
             ?assertEqual(Bytes, Reassembled)
         end}
    ]).

missing_file_test_() ->
    with_setup([
        {"unknown file_id aborts with not_available",
         fun() ->
             %% File absent — CEK lookup never runs.
             {ok, S} = macula:call_stream(?PROC,
                 #{<<"file_id">> => <<"nonexistent000000000000000000000">>}),
             ?assertMatch({error, {<<"not_available">>, _}},
                          macula:recv(S, 1000))
         end}
    ]).

no_cek_test_() ->
    with_setup([
        {"file present but no CEK in my_issued_files aborts with no_cek",
         fun() ->
             ok = briefcase_content_store:put(?FILE_ID, <<"payload">>),
             clear_cek(?FILE_ID),
             {ok, S} = macula:call_stream(?PROC,
                 #{<<"file_id">> => ?FILE_ID}),
             ?assertMatch({error, {<<"no_cek">>, _}},
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

%% Drain the stream, decoding each chunk as a hecate_file_frame and
%% decrypting with `Cek`. Partial-frame reassembly for the case where
%% a macula chunk ends mid-frame.
drain_and_decrypt(Stream, Cek) ->
    drain_loop(Stream, Cek, <<>>, <<>>, 0).

drain_loop(Stream, Cek, Buf, Plain, Chunks) ->
    case macula:recv(Stream, 2000) of
        {chunk, Bin} ->
            NewBuf = <<Buf/binary, Bin/binary>>,
            {NewBuf2, NewPlain, NewChunks} =
                peel_frames(NewBuf, Cek, Plain, Chunks),
            drain_loop(Stream, Cek, NewBuf2, NewPlain, NewChunks);
        eof ->
            ?assert(Chunks >= 1),
            Plain;
        Other ->
            erlang:error({unexpected, Other})
    end.

peel_frames(Buf, Cek, Plain, Chunks) ->
    case hecate_file_frame:decode_frame(Buf) of
        {ok, Envelope, Rest} ->
            {ok, Pt} = hecate_file_frame:decrypt_envelope(Cek, Envelope),
            peel_frames(Rest, Cek, <<Plain/binary, Pt/binary>>, Chunks + 1);
        eof ->
            %% Zero-length frame — upstream will get a matching eof
            %% from macula shortly.
            {<<>>, Plain, Chunks};
        {more, _Needed} ->
            {Buf, Plain, Chunks}
    end.
