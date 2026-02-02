%%%-------------------------------------------------------------------
%%% @doc Tests for hecate_identity module.
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
            {"is_initialized returns false when no identity", fun not_initialized/0},
            {"get_mri returns not_initialized when no identity", fun get_mri_not_initialized/0},
            {"get_realm returns not_initialized when no identity", fun get_realm_not_initialized/0},
            {"get_public_key returns not_initialized when no identity", fun get_pubkey_not_initialized/0},
            {"sign returns not_initialized when no identity", fun sign_not_initialized/0},
            {"initialize creates new identity", fun initialize_creates_identity/0},
            {"initialize with custom options", fun initialize_with_options/0},
            {"initialize twice returns error", fun initialize_twice_error/0},
            {"sign and verify roundtrip", fun sign_verify_roundtrip/0},
            {"verify with wrong signature fails", fun verify_wrong_signature/0},
            {"mri format is correct", fun mri_format/0}
        ]
    }.

%%====================================================================
%% Setup / Cleanup
%%====================================================================

setup() ->
    TempDir = "/tmp/hecate_identity_test_" ++ integer_to_list(erlang:unique_integer([positive])),
    ok = filelib:ensure_dir(filename:join(TempDir, "dummy")),
    application:set_env(hecate, data_dir, TempDir),
    
    
    {ok, _} = application:ensure_all_started(esqlite),
    
    %% Start store first (identity depends on it)
    {ok, StorePid} = hecate_store:start_link(),
    {ok, IdentityPid} = hecate_identity:start_link(),
    
    {StorePid, IdentityPid, TempDir}.

cleanup({StorePid, IdentityPid, TempDir}) ->
    gen_server:stop(IdentityPid),
    gen_server:stop(StorePid),
    os:cmd("rm -rf " ++ TempDir),
    ok.

%%====================================================================
%% Test Cases
%%====================================================================

not_initialized() ->
    ?assertEqual(false, hecate_identity:is_initialized()).

get_mri_not_initialized() ->
    ?assertEqual(not_initialized, hecate_identity:get_mri()).

get_realm_not_initialized() ->
    ?assertEqual(not_initialized, hecate_identity:get_realm()).

get_pubkey_not_initialized() ->
    ?assertEqual(not_initialized, hecate_identity:get_public_key()).

sign_not_initialized() ->
    ?assertEqual(not_initialized, hecate_identity:sign(<<"data">>)).

initialize_creates_identity() ->
    ?assertEqual(ok, hecate_identity:initialize(#{})),
    ?assertEqual(true, hecate_identity:is_initialized()),
    
    {ok, MRI} = hecate_identity:get_mri(),
    ?assert(is_binary(MRI)),
    ?assertMatch(<<"mri:agent:", _/binary>>, MRI),
    
    {ok, Realm} = hecate_identity:get_realm(),
    ?assertEqual(<<"io.macula">>, Realm),
    
    {ok, PubKey} = hecate_identity:get_public_key(),
    ?assertEqual(32, byte_size(PubKey)). %% Ed25519 public key is 32 bytes

initialize_with_options() ->
    ok = hecate_identity:initialize(#{
        realm => <<"custom.realm">>,
        owner => <<"testowner">>,
        name => <<"myagent">>
    }),
    
    {ok, MRI} = hecate_identity:get_mri(),
    ?assertEqual(<<"mri:agent:custom.realm/testowner/myagent">>, MRI),
    
    {ok, Realm} = hecate_identity:get_realm(),
    ?assertEqual(<<"custom.realm">>, Realm).

initialize_twice_error() ->
    ok = hecate_identity:initialize(#{}),
    ?assertEqual({error, already_initialized}, hecate_identity:initialize(#{})).

sign_verify_roundtrip() ->
    ok = hecate_identity:initialize(#{}),
    
    Data = <<"test data to sign">>,
    {ok, Signature} = hecate_identity:sign(Data),
    
    ?assert(is_binary(Signature)),
    ?assertEqual(64, byte_size(Signature)), %% Ed25519 signature is 64 bytes
    
    ?assertEqual(true, hecate_identity:verify(Data, Signature)).

verify_wrong_signature() ->
    ok = hecate_identity:initialize(#{}),
    
    Data = <<"original data">>,
    {ok, Signature} = hecate_identity:sign(Data),
    
    %% Verify with different data should fail
    ?assertEqual(false, hecate_identity:verify(<<"different data">>, Signature)),
    
    %% Verify with corrupted signature should fail
    <<First, Rest/binary>> = Signature,
    CorruptedSig = <<(First bxor 255), Rest/binary>>,
    ?assertEqual(false, hecate_identity:verify(Data, CorruptedSig)).

mri_format() ->
    ok = hecate_identity:initialize(#{
        realm => <<"test.realm">>,
        owner => <<"owner">>,
        name => <<"agent">>
    }),
    
    {ok, MRI} = hecate_identity:get_mri(),
    
    %% Parse MRI format: mri:agent:realm/owner/name
    ?assertMatch(<<"mri:agent:", _/binary>>, MRI),
    
    <<"mri:agent:", Rest/binary>> = MRI,
    Parts = binary:split(Rest, <<"/">>, [global]),
    ?assertEqual(3, length(Parts)),
    
    [Realm, Owner, Name] = Parts,
    ?assertEqual(<<"test.realm">>, Realm),
    ?assertEqual(<<"owner">>, Owner),
    ?assertEqual(<<"agent">>, Name).
