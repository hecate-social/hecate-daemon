%%%-------------------------------------------------------------------
%%% @doc Tests for hecate_identity module.
%%%
%%% Since v0.11.1, hecate_identity auto-initializes on first boot.
%%% Tests verify auto-init behavior and pre-seeded identity loading.
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
            {"loads pre-seeded identity from store", fun loads_from_store/0},
            {"initialize returns already_initialized", fun initialize_already_init/0},
            {"sign and verify roundtrip", fun sign_verify_roundtrip/0},
            {"verify with wrong signature fails", fun verify_wrong_signature/0},
            {"MRI format with custom identity", fun mri_format_custom/0}
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

    %% Ensure clean state
    catch gen_server:stop(hecate_identity),
    catch gen_server:stop(hecate_store),

    {ok, StorePid} = hecate_store:start_link(),
    {StorePid, TempDir}.

cleanup({_StorePid, TempDir}) ->
    catch gen_server:stop(hecate_identity),
    catch gen_server:stop(hecate_store),
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

loads_from_store() ->
    %% Pre-seed identity in store
    {PubKey, PrivKey} = crypto:generate_key(eddsa, ed25519),
    ok = hecate_store:put(<<"identity">>, <<"identity">>, #{
        mri => <<"mri:agent:test.realm/testowner/myagent">>,
        realm => <<"test.realm">>,
        public_key => PubKey,
        private_key => PrivKey,
        created_at => erlang:system_time(second)
    }),

    {ok, _} = hecate_identity:start_link(),

    %% Should load the pre-seeded identity, not auto-generate
    {ok, MRI} = hecate_identity:get_mri(),
    ?assertEqual(<<"mri:agent:test.realm/testowner/myagent">>, MRI),
    {ok, Realm} = hecate_identity:get_realm(),
    ?assertEqual(<<"test.realm">>, Realm).

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

    %% Verify with different data should fail
    ?assertEqual(false, hecate_identity:verify(<<"different data">>, Signature)),

    %% Verify with corrupted signature should fail
    <<First, Rest/binary>> = Signature,
    CorruptedSig = <<(First bxor 255), Rest/binary>>,
    ?assertEqual(false, hecate_identity:verify(Data, CorruptedSig)).

mri_format_custom() ->
    %% Pre-seed identity with custom realm/owner/name
    {PubKey, PrivKey} = crypto:generate_key(eddsa, ed25519),
    ok = hecate_store:put(<<"identity">>, <<"identity">>, #{
        mri => <<"mri:agent:test.realm/owner/agent">>,
        realm => <<"test.realm">>,
        public_key => PubKey,
        private_key => PrivKey,
        created_at => erlang:system_time(second)
    }),

    {ok, _} = hecate_identity:start_link(),

    {ok, MRI} = hecate_identity:get_mri(),

    %% Parse MRI format: mri:agent:realm/owner/name
    ?assertMatch(<<"mri:agent:", _/binary>>, MRI),

    <<"mri:agent:", MriRest/binary>> = MRI,
    Parts = binary:split(MriRest, <<"/">>, [global]),
    ?assertEqual(3, length(Parts)),

    [Realm, Owner, Name] = Parts,
    ?assertEqual(<<"test.realm">>, Realm),
    ?assertEqual(<<"owner">>, Owner),
    ?assertEqual(<<"agent">>, Name).
