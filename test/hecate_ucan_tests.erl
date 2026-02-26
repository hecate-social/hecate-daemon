%%%-------------------------------------------------------------------
%%% @doc Tests for hecate_ucan module.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_ucan_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Test Descriptions
%%====================================================================

ucan_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"list returns empty when no capabilities", fun list_empty/0},
            {"grant creates capability", fun grant_capability/0},
            {"grant returns unique id", fun grant_unique_ids/0},
            {"grant sets correct fields", fun grant_fields/0},
            {"revoke removes capability", fun revoke_capability/0},
            {"revoke non-existent returns error", fun revoke_not_found/0},
            {"list returns all capabilities", fun list_capabilities/0},
            {"capability has signature", fun capability_signature/0},
            {"verify returns not_implemented", fun verify_not_implemented/0}
        ]
    }.

%%====================================================================
%% Setup / Cleanup
%%====================================================================

setup() ->
    TempDir = "/tmp/hecate_ucan_test_" ++ integer_to_list(erlang:unique_integer([positive])),
    ok = filelib:ensure_dir(filename:join(TempDir, "dummy")),
    application:set_env(hecate, data_dir, TempDir),

    {ok, _} = application:ensure_all_started(esqlite),
    {ok, _} = application:ensure_all_started(jsx),

    %% Ensure clean state — stop any leftover processes from previous test
    catch gen_server:stop(hecate_ucan),
    catch gen_server:stop(hecate_identity),
    catch gen_server:stop(hecate_store),

    {ok, StorePid} = hecate_store:start_link(),

    %% Pre-seed identity so hecate_identity loads it from store
    %% instead of auto-generating a random MRI
    {PubKey, PrivKey} = crypto:generate_key(eddsa, ed25519),
    ok = hecate_store:put(<<"identity">>, <<"identity">>, #{
        mri => <<"mri:agent:test.realm/test/ucan-test">>,
        realm => <<"test.realm">>,
        public_key => PubKey,
        private_key => PrivKey,
        created_at => erlang:system_time(second)
    }),

    {ok, IdentityPid} = hecate_identity:start_link(),
    {ok, UcanPid} = hecate_ucan:start_link(),

    {StorePid, IdentityPid, UcanPid, TempDir}.

cleanup({_StorePid, _IdentityPid, _UcanPid, TempDir}) ->
    catch gen_server:stop(hecate_ucan),
    catch gen_server:stop(hecate_identity),
    catch gen_server:stop(hecate_store),
    os:cmd("rm -rf " ++ TempDir),
    ok.

%%====================================================================
%% Test Cases
%%====================================================================

list_empty() ->
    ?assertEqual([], hecate_ucan:list()).

grant_capability() ->
    {ok, Id} = hecate_ucan:grant(
        <<"mri:agent:test.realm/other/agent">>,
        <<"mesh/publish">>,
        <<"topic:events.*">>
    ),
    
    ?assert(is_binary(Id)),
    ?assert(byte_size(Id) > 0).

grant_unique_ids() ->
    {ok, Id1} = hecate_ucan:grant(<<"a">>, <<"can1">>, <<"res1">>),
    {ok, Id2} = hecate_ucan:grant(<<"b">>, <<"can2">>, <<"res2">>),
    {ok, Id3} = hecate_ucan:grant(<<"c">>, <<"can3">>, <<"res3">>),
    
    ?assertNotEqual(Id1, Id2),
    ?assertNotEqual(Id2, Id3),
    ?assertNotEqual(Id1, Id3).

grant_fields() ->
    To = <<"mri:agent:test.realm/recipient/agent">>,
    Can = <<"mesh/rpc">>,
    Resource = <<"procedure:echo">>,
    
    {ok, Id} = hecate_ucan:grant(To, Can, Resource),
    
    [Cap] = hecate_ucan:list(),
    
    ?assertEqual(Id, maps:get(id, Cap)),
    ?assertEqual(<<"mri:agent:test.realm/test/ucan-test">>, maps:get(iss, Cap)),
    ?assertEqual(To, maps:get(aud, Cap)),
    
    %% Check attestations
    [Att] = maps:get(att, Cap),
    ?assertEqual(Resource, maps:get(with, Att)),
    ?assertEqual(Can, maps:get(can, Att)),
    
    %% Check expiration is in the future (7 days default)
    Exp = maps:get(exp, Cap),
    Now = erlang:system_time(second),
    ?assert(Exp > Now),
    ?assert(Exp =< Now + (7 * 24 * 3600) + 1).

revoke_capability() ->
    {ok, Id} = hecate_ucan:grant(<<"a">>, <<"b">>, <<"c">>),
    ?assertEqual(1, length(hecate_ucan:list())),
    
    ?assertEqual(ok, hecate_ucan:revoke(Id)),
    ?assertEqual(0, length(hecate_ucan:list())).

revoke_not_found() ->
    ?assertEqual({error, not_found}, hecate_ucan:revoke(<<"nonexistent">>)).

list_capabilities() ->
    {ok, _} = hecate_ucan:grant(<<"a">>, <<"can1">>, <<"res1">>),
    {ok, _} = hecate_ucan:grant(<<"b">>, <<"can2">>, <<"res2">>),
    {ok, _} = hecate_ucan:grant(<<"c">>, <<"can3">>, <<"res3">>),
    
    Caps = hecate_ucan:list(),
    ?assertEqual(3, length(Caps)),
    
    %% All should be maps with required fields
    lists:foreach(fun(Cap) ->
        ?assert(maps:is_key(id, Cap)),
        ?assert(maps:is_key(iss, Cap)),
        ?assert(maps:is_key(aud, Cap)),
        ?assert(maps:is_key(att, Cap)),
        ?assert(maps:is_key(exp, Cap))
    end, Caps).

capability_signature() ->
    {ok, _} = hecate_ucan:grant(<<"a">>, <<"b">>, <<"c">>),
    
    [Cap] = hecate_ucan:list(),
    
    ?assert(maps:is_key(signature, Cap)),
    Sig = maps:get(signature, Cap),
    ?assert(is_binary(Sig)),
    
    %% Signature should be base64 encoded (decoding should not throw)
    Decoded = base64:decode(Sig),
    ?assert(is_binary(Decoded)).

verify_not_implemented() ->
    ?assertEqual({error, not_implemented}, hecate_ucan:verify(<<"token">>)).
