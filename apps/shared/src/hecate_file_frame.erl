%%% @doc Self-describing chunked framing for AES-256-GCM encrypted
%%% file content.
%%%
%%% Each frame on the wire:
%%% ```
%%%   u32 BE  — length of envelope (0 signals EOF)
%%%   envelope:
%%%     12 bytes nonce
%%%     16 bytes GCM authentication tag
%%%     N  bytes ciphertext  (N = plaintext chunk size)
%%% ```
%%%
%%% EOF is an explicit zero-length frame so a peer can distinguish
%%% graceful close from a truncated stream. Every chunk is
%%% independently decryptable — the recipient does not have to buffer
%%% more than one frame at a time.
%%%
%%% Same envelope shape as `hecate_realm_crypto:wrap/2` output so
%%% `crypto:crypto_one_time_aead/7` can be used directly on the
%%% envelope bytes.
%%% @end
-module(hecate_file_frame).

-export([encode_chunk/2, encode_eof/0]).
-export([decode_frame/1, decrypt_envelope/2]).
-export([nonce_size/0, tag_size/0, header_overhead/0]).

-define(LEN_BYTES, 4).
-define(NONCE_SIZE, 12).
-define(TAG_SIZE, 16).

-type key()        :: <<_:256>>.
-type plaintext()  :: binary().
-type frame()      :: binary().

%%====================================================================
%% Encoder
%%====================================================================

%% @doc Encrypt `Plaintext` with `Key`, return a wire frame ready to
%% transmit. Includes the u32 length prefix.
-spec encode_chunk(key(), plaintext()) -> frame().
encode_chunk(Key, Plaintext)
  when is_binary(Key), byte_size(Key) == 32,
       is_binary(Plaintext) ->
    Nonce = crypto:strong_rand_bytes(?NONCE_SIZE),
    {Cipher, Tag} = crypto:crypto_one_time_aead(
        aes_256_gcm, Key, Nonce, Plaintext, <<>>, true),
    Envelope = <<Nonce:?NONCE_SIZE/binary,
                 Tag:?TAG_SIZE/binary,
                 Cipher/binary>>,
    Len = byte_size(Envelope),
    <<Len:32/big, Envelope/binary>>.

%% @doc EOF marker — a frame with length 0.
-spec encode_eof() -> frame().
encode_eof() ->
    <<0:32/big>>.

%%====================================================================
%% Decoder
%%====================================================================

%% @doc Peel ONE frame off the front of `Buf`. Returns:
%%   `{ok, Envelope, Rest}`     — full frame parsed
%%   `eof`                       — encountered zero-length frame
%%   `{more, Needed}`            — Buf too short; callers should read
%%                                 `Needed` more bytes then retry
%%   `{error, Reason}`           — malformed input
%%
%% The caller must still call `decrypt_envelope/2` to turn the
%% envelope into plaintext. Keeping decoding + decryption separate
%% lets streaming consumers batch the read then decrypt inline.
-spec decode_frame(binary()) ->
    {ok, binary(), binary()}
    | eof
    | {more, pos_integer()}
    | {error, term()}.
decode_frame(Buf) when is_binary(Buf), byte_size(Buf) < ?LEN_BYTES ->
    {more, ?LEN_BYTES - byte_size(Buf)};
decode_frame(<<0:32/big, Rest/binary>>) ->
    case Rest of
        <<>> -> eof;
        _    -> {error, trailing_bytes_after_eof}
    end;
decode_frame(<<Len:32/big, _Body/binary>>)
  when Len < ?NONCE_SIZE + ?TAG_SIZE ->
    {error, {frame_too_small, Len}};
decode_frame(<<Len:32/big, Body/binary>>)
  when byte_size(Body) < Len ->
    {more, Len - byte_size(Body)};
decode_frame(<<Len:32/big, Envelope:Len/binary, Rest/binary>>) ->
    {ok, Envelope, Rest}.

%% @doc Decrypt an envelope (output of `decode_frame/1`) with `Key`.
%% Returns the plaintext bytes of the chunk, or `{error, bad_ciphertext}`
%% on tag mismatch / short envelope.
-spec decrypt_envelope(key(), binary()) ->
    {ok, plaintext()} | {error, term()}.
decrypt_envelope(Key,
                 <<Nonce:?NONCE_SIZE/binary,
                   Tag:?TAG_SIZE/binary,
                   Cipher/binary>>)
  when is_binary(Key), byte_size(Key) == 32 ->
    case crypto:crypto_one_time_aead(
           aes_256_gcm, Key, Nonce, Cipher, <<>>, Tag, false) of
        Plaintext when is_binary(Plaintext) -> {ok, Plaintext};
        error                                -> {error, bad_ciphertext}
    end;
decrypt_envelope(_Key, _Bad) ->
    {error, bad_envelope}.

%%====================================================================
%% Accessors
%%====================================================================

-spec nonce_size() -> pos_integer().
nonce_size() -> ?NONCE_SIZE.

-spec tag_size() -> pos_integer().
tag_size() -> ?TAG_SIZE.

%% @doc Bytes of per-frame overhead (length prefix + nonce + tag).
-spec header_overhead() -> pos_integer().
header_overhead() -> ?LEN_BYTES + ?NONCE_SIZE + ?TAG_SIZE.
