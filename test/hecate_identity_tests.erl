%%%-------------------------------------------------------------------
%%% @doc Tests for hecate_identity module.
%%%
%%% Identity now persists as an encrypted file, not SQLite.
%%% Tests verify auto-init, file persistence, and crypto operations.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_identity_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Test Descriptions
%%====================================================================

identity_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"auto-initializes on start", fun auto_initializes/0},
            {"auto-init creates valid MRI", fun auto_init_mri/0},
            {"auto-init uses default realm", fun auto_init_realm/0},
            {"auto-init creates Ed25519 key", fun auto_init_key/0},
            {"persists identity to encrypted file", fun persists_to_file/0},
            {"initialize returns already_initialized", fun initialize_already_init/0},
            {"sign and verify roundtrip", fun sign_verify_roundtrip/0},
            {"verify with wrong signature fails", fun verify_wrong_signature/0}
        ]
    }.

%%====================================================================
%% Setup / Cleanup
%%====================================================================

setup() ->
    TempDir = "/tmp/hecate_identity_test_" ++ integer_to_list(erlang:unique_integer([positive])),
    ok = filelib:ensure_dir(filename:join(TempDir, "dummy")),
    application:set_env(hecate, data_dir, TempDir),
    catch gen_server:stop(hecate_identity),
    TempDir.

cleanup(TempDir) ->
    catch gen_server:stop(hecate_identity),
    os:cmd("rm -rf " ++ TempDir),
    ok.

%%====================================================================
%% Test Cases
%%====================================================================

auto_initializes() ->
    {ok, _} = hecate_identity:start_link(),
    ?assertEqual(true, hecate_identity:is_initialized()).

auto_init_mri() ->
    {ok, _} = hecate_identity:start_link(),
    {ok, MRI} = hecate_identity:get_mri(),
    ?assert(is_binary(MRI)),
    ?assertMatch(<<"mri:agent:", _/binary>>, MRI).

auto_init_realm() ->
    {ok, _} = hecate_identity:start_link(),
    {ok, Realm} = hecate_identity:get_realm(),
    ?assertEqual(<<"io.macula">>, Realm).

auto_init_key() ->
    {ok, _} = hecate_identity:start_link(),
    {ok, PubKey} = hecate_identity:get_public_key(),
    ?assertEqual(32, byte_size(PubKey)).

persists_to_file() ->
    %% First start creates identity and writes file
    {ok, _} = hecate_identity:start_link(),
    {ok, MRI1} = hecate_identity:get_mri(),
    {ok, PubKey1} = hecate_identity:get_public_key(),
    gen_server:stop(hecate_identity),

    %% Second start loads from encrypted file
    {ok, _} = hecate_identity:start_link(),
    {ok, MRI2} = hecate_identity:get_mri(),
    {ok, PubKey2} = hecate_identity:get_public_key(),

    ?assertEqual(MRI1, MRI2),
    ?assertEqual(PubKey1, PubKey2).

initialize_already_init() ->
    {ok, _} = hecate_identity:start_link(),
    ?assertEqual({error, already_initialized}, hecate_identity:initialize(#{})).

sign_verify_roundtrip() ->
    {ok, _} = hecate_identity:start_link(),

    Data = <<"test data to sign">>,
    {ok, Signature} = hecate_identity:sign(Data),

    ?assert(is_binary(Signature)),
    ?assertEqual(64, byte_size(Signature)),
    ?assertEqual(true, hecate_identity:verify(Data, Signature)).

verify_wrong_signature() ->
    {ok, _} = hecate_identity:start_link(),

    Data = <<"original data">>,
    {ok, Signature} = hecate_identity:sign(Data),

    ?assertEqual(false, hecate_identity:verify(<<"different data">>, Signature)),

    <<First, Rest/binary>> = Signature,
    CorruptedSig = <<(First bxor 255), Rest/binary>>,
    ?assertEqual(false, hecate_identity:verify(Data, CorruptedSig)).
