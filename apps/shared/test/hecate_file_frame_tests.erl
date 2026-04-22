-module(hecate_file_frame_tests).
-include_lib("eunit/include/eunit.hrl").

roundtrip_small_test() ->
    Key = crypto:strong_rand_bytes(32),
    Plain = <<"hello world">>,
    Frame = hecate_file_frame:encode_chunk(Key, Plain),
    {ok, Env, <<>>} = hecate_file_frame:decode_frame(Frame),
    {ok, Plain} = hecate_file_frame:decrypt_envelope(Key, Env).

roundtrip_empty_plaintext_test() ->
    Key = crypto:strong_rand_bytes(32),
    Frame = hecate_file_frame:encode_chunk(Key, <<>>),
    {ok, Env, <<>>} = hecate_file_frame:decode_frame(Frame),
    {ok, <<>>} = hecate_file_frame:decrypt_envelope(Key, Env).

roundtrip_64kb_test() ->
    Key = crypto:strong_rand_bytes(32),
    Plain = crypto:strong_rand_bytes(65536),
    Frame = hecate_file_frame:encode_chunk(Key, Plain),
    {ok, Env, <<>>} = hecate_file_frame:decode_frame(Frame),
    {ok, Decrypted} = hecate_file_frame:decrypt_envelope(Key, Env),
    ?assertEqual(Plain, Decrypted).

multi_frame_buffer_peeled_in_sequence_test() ->
    Key = crypto:strong_rand_bytes(32),
    F1 = hecate_file_frame:encode_chunk(Key, <<"frame 1">>),
    F2 = hecate_file_frame:encode_chunk(Key, <<"frame 2">>),
    F3 = hecate_file_frame:encode_chunk(Key, <<"frame 3">>),
    Buf = <<F1/binary, F2/binary, F3/binary,
            (hecate_file_frame:encode_eof())/binary>>,
    {ok, E1, R1} = hecate_file_frame:decode_frame(Buf),
    {ok, E2, R2} = hecate_file_frame:decode_frame(R1),
    {ok, E3, R3} = hecate_file_frame:decode_frame(R2),
    ?assertEqual(eof, hecate_file_frame:decode_frame(R3)),
    {ok, <<"frame 1">>} = hecate_file_frame:decrypt_envelope(Key, E1),
    {ok, <<"frame 2">>} = hecate_file_frame:decrypt_envelope(Key, E2),
    {ok, <<"frame 3">>} = hecate_file_frame:decrypt_envelope(Key, E3).

partial_length_prefix_more_test() ->
    %% Only 2 of the 4 length bytes present.
    ?assertEqual({more, 2}, hecate_file_frame:decode_frame(<<0, 0>>)).

partial_envelope_more_test() ->
    Key = crypto:strong_rand_bytes(32),
    Frame = hecate_file_frame:encode_chunk(Key, <<"payload">>),
    %% Truncate to 4 (length prefix) + 10 (partial envelope).
    Truncated = binary:part(Frame, 0, 14),
    ?assertMatch({more, _N}, hecate_file_frame:decode_frame(Truncated)).

eof_frame_test() ->
    Eof = hecate_file_frame:encode_eof(),
    ?assertEqual(eof, hecate_file_frame:decode_frame(Eof)).

wrong_key_fails_decryption_test() ->
    Key1 = crypto:strong_rand_bytes(32),
    Key2 = crypto:strong_rand_bytes(32),
    Frame = hecate_file_frame:encode_chunk(Key1, <<"secret">>),
    {ok, Env, <<>>} = hecate_file_frame:decode_frame(Frame),
    ?assertEqual({error, bad_ciphertext},
                 hecate_file_frame:decrypt_envelope(Key2, Env)).

tampered_ciphertext_fails_test() ->
    Key = crypto:strong_rand_bytes(32),
    Frame = hecate_file_frame:encode_chunk(Key, <<"payload">>),
    {ok, Env0, <<>>} = hecate_file_frame:decode_frame(Frame),
    %% Flip a byte in the ciphertext region (after nonce+tag).
    <<Head:28/binary, First:8, Rest/binary>> = Env0,
    Env = <<Head/binary, (First bxor 16#FF):8, Rest/binary>>,
    ?assertEqual({error, bad_ciphertext},
                 hecate_file_frame:decrypt_envelope(Key, Env)).

frame_too_small_rejected_test() ->
    %% Length says 10 bytes but nonce alone is 12 — nonsense.
    Bad = <<10:32/big, 0:80>>,
    ?assertMatch({error, {frame_too_small, 10}},
                 hecate_file_frame:decode_frame(Bad)).
