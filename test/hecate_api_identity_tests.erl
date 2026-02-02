%%%-------------------------------------------------------------------
%%% @doc Tests for hecate_api_identity handler.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_identity_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Test Descriptions
%%====================================================================

identity_api_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"returns identity when initialized", fun returns_identity/0},
            {"returns error when not initialized", fun returns_not_initialized/0},
            {"public key is base64 encoded", fun pubkey_base64/0}
        ]
    }.

%%====================================================================
%% Setup / Cleanup
%%====================================================================

setup() ->
    
    {ok, _} = application:ensure_all_started(jsx),
    
    meck:new(hecate_identity, [passthrough]),
    meck:new(cowboy_req, [passthrough]),
    
    meck:expect(cowboy_req, reply, fun(Status, Headers, Body, Req) ->
        put(last_response, {Status, Headers, Body}),
        Req
    end),
    
    ok.

cleanup(_) ->
    meck:unload(hecate_identity),
    meck:unload(cowboy_req),
    erase(last_response),
    ok.

%%====================================================================
%% Test Cases
%%====================================================================

returns_identity() ->
    PubKey = crypto:strong_rand_bytes(32),
    
    meck:expect(hecate_identity, is_initialized, fun() -> true end),
    meck:expect(hecate_identity, get_mri, fun() -> {ok, <<"mri:agent:test/owner/agent">>} end),
    meck:expect(hecate_identity, get_realm, fun() -> {ok, <<"test">>} end),
    meck:expect(hecate_identity, get_public_key, fun() -> {ok, PubKey} end),
    
    {ok, _Req, _State} = hecate_api_identity:init(#{}, []),
    
    {200, _Headers, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    
    ?assertEqual(true, maps:get(<<"ok">>, Decoded)),
    ?assertEqual(<<"mri:agent:test/owner/agent">>, maps:get(<<"mri">>, Decoded)),
    ?assertEqual(<<"test">>, maps:get(<<"realm">>, Decoded)),
    ?assert(maps:is_key(<<"public_key">>, Decoded)).

returns_not_initialized() ->
    meck:expect(hecate_identity, is_initialized, fun() -> false end),
    
    {ok, _Req, _State} = hecate_api_identity:init(#{}, []),
    
    {200, _Headers, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    
    ?assertEqual(false, maps:get(<<"ok">>, Decoded)),
    ?assertEqual(<<"not_initialized">>, maps:get(<<"error">>, Decoded)),
    ?assert(maps:is_key(<<"hint">>, Decoded)).

pubkey_base64() ->
    PubKey = crypto:strong_rand_bytes(32),
    ExpectedEncoded = base64:encode(PubKey),
    
    meck:expect(hecate_identity, is_initialized, fun() -> true end),
    meck:expect(hecate_identity, get_mri, fun() -> {ok, <<"mri:agent:test/o/a">>} end),
    meck:expect(hecate_identity, get_realm, fun() -> {ok, <<"test">>} end),
    meck:expect(hecate_identity, get_public_key, fun() -> {ok, PubKey} end),
    
    {ok, _Req, _State} = hecate_api_identity:init(#{}, []),
    
    {200, _Headers, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    
    EncodedKey = maps:get(<<"public_key">>, Decoded),
    ?assertEqual(ExpectedEncoded, EncodedKey),
    
    %% Should decode back to original
    ?assertEqual(PubKey, base64:decode(EncodedKey)).
