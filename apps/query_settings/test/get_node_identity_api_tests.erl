%%%-------------------------------------------------------------------
%%% @doc Tests for get_node_identity_api handler.
%%% @end
%%%-------------------------------------------------------------------
-module(get_node_identity_api_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Test Descriptions
%%====================================================================

get_node_identity_api_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"returns identity when initialized", fun returns_identity_initialized/0},
            {"returns initialized false when not initialized", fun returns_not_initialized/0},
            {"base64 encodes public key", fun base64_encodes_key/0},
            {"rejects non-GET methods", fun rejects_non_get/0}
        ]
    }.

%%====================================================================
%% Setup / Cleanup
%%====================================================================

setup() ->
    meck:new(hecate_identity, [passthrough]),
    meck:new(cowboy_req, [passthrough]),
    meck:expect(cowboy_req, reply, fun(Status, Headers, Body, Req) ->
        put(last_response, {Status, Headers, Body}),
        Req
    end),
    meck:expect(cowboy_req, method, fun(_Req) -> <<"GET">> end),
    ok.

cleanup(_) ->
    meck:unload(hecate_identity),
    meck:unload(cowboy_req),
    erase(last_response),
    ok.

%%====================================================================
%% Test Cases
%%====================================================================

returns_identity_initialized() ->
    MRI = <<"mri:agent:io.macula/anonymous/hecate-a1b2">>,
    PubKey = crypto:strong_rand_bytes(32),
    Realm = <<"io.macula">>,

    meck:expect(hecate_identity, is_initialized, fun() -> true end),
    meck:expect(hecate_identity, get_mri, fun() -> {ok, MRI} end),
    meck:expect(hecate_identity, get_public_key, fun() -> {ok, PubKey} end),
    meck:expect(hecate_identity, get_realm, fun() -> {ok, Realm} end),

    {ok, _Req, _State} = get_node_identity_api:init(#{}, []),

    {200, _, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),

    ?assertEqual(true, maps:get(<<"ok">>, Decoded)),
    NodeId = maps:get(<<"node_identity">>, Decoded),
    ?assertEqual(MRI, maps:get(<<"mri">>, NodeId)),
    ?assertEqual(Realm, maps:get(<<"realm">>, NodeId)),
    ?assertEqual(true, maps:get(<<"initialized">>, NodeId)).

returns_not_initialized() ->
    meck:expect(hecate_identity, is_initialized, fun() -> false end),

    {ok, _Req, _State} = get_node_identity_api:init(#{}, []),

    {200, _, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),

    ?assertEqual(true, maps:get(<<"ok">>, Decoded)),
    NodeId = maps:get(<<"node_identity">>, Decoded),
    ?assertEqual(false, maps:get(<<"initialized">>, NodeId)).

base64_encodes_key() ->
    PubKey = <<1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,
               17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32>>,
    ExpectedB64 = base64:encode(PubKey),

    meck:expect(hecate_identity, is_initialized, fun() -> true end),
    meck:expect(hecate_identity, get_mri, fun() -> {ok, <<"mri:agent:test">>} end),
    meck:expect(hecate_identity, get_public_key, fun() -> {ok, PubKey} end),
    meck:expect(hecate_identity, get_realm, fun() -> {ok, <<"test">>} end),

    {ok, _Req, _State} = get_node_identity_api:init(#{}, []),

    {200, _, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    NodeId = maps:get(<<"node_identity">>, Decoded),
    ?assertEqual(ExpectedB64, maps:get(<<"public_key">>, NodeId)).

rejects_non_get() ->
    meck:expect(cowboy_req, method, fun(_Req) -> <<"POST">> end),

    {ok, _Req, _State} = get_node_identity_api:init(#{}, []),

    {405, _, _Body} = get(last_response).
