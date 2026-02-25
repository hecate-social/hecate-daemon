%%%-------------------------------------------------------------------
%%% @doc Tests for pairing API handlers:
%%%   - initiate_pairing_api (POST /api/pairing/initiate)
%%%   - get_pairing_status_api (GET /api/pairing/status)
%%%   - cancel_pairing_api (POST /api/pairing/cancel)
%%% @end
%%%-------------------------------------------------------------------
-module(pairing_api_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Test Descriptions
%%====================================================================

initiate_pairing_api_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"returns session data on success", fun initiate_success/0},
            {"returns 500 on pairing error", fun initiate_error/0},
            {"rejects non-POST methods", fun initiate_rejects_get/0}
        ]
    }.

get_pairing_status_api_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"returns idle status", fun status_idle/0},
            {"returns pairing status with session data", fun status_pairing/0},
            {"returns paired status", fun status_paired/0},
            {"rejects non-GET methods", fun status_rejects_post/0}
        ]
    }.

cancel_pairing_api_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"cancels and returns ok", fun cancel_success/0},
            {"rejects non-POST methods", fun cancel_rejects_get/0}
        ]
    }.

%%====================================================================
%% Setup / Cleanup
%%====================================================================

setup() ->
    meck:new(hecate_pairing, [passthrough]),
    meck:new(cowboy_req, [passthrough]),
    meck:expect(cowboy_req, reply, fun(Status, Headers, Body, Req) ->
        put(last_response, {Status, Headers, Body}),
        Req
    end),
    %% Default to POST for initiate/cancel tests
    meck:expect(cowboy_req, method, fun(_Req) -> <<"POST">> end),
    ok.

cleanup(_) ->
    meck:unload(hecate_pairing),
    meck:unload(cowboy_req),
    erase(last_response),
    ok.

%%====================================================================
%% initiate_pairing_api tests
%%====================================================================

initiate_success() ->
    SessionData = #{
        session_id => <<"sess-123">>,
        confirm_code => <<"ABC123">>,
        pairing_url => <<"https://macula.io/pair/sess-123">>,
        expires_in => 600
    },
    meck:expect(hecate_pairing, start_pairing, fun() -> {ok, SessionData} end),

    {ok, _Req, _State} = initiate_pairing_api:init(#{}, []),

    {200, _, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    ?assertEqual(true, maps:get(<<"ok">>, Decoded)),
    ?assertEqual(<<"sess-123">>, maps:get(<<"session_id">>, Decoded)),
    ?assertEqual(<<"ABC123">>, maps:get(<<"confirm_code">>, Decoded)),
    ?assertEqual(<<"https://macula.io/pair/sess-123">>, maps:get(<<"pairing_url">>, Decoded)),
    ?assertEqual(600, maps:get(<<"expires_in">>, Decoded)).

initiate_error() ->
    meck:expect(hecate_pairing, start_pairing, fun() ->
        {error, identity_not_initialized}
    end),

    {ok, _Req, _State} = initiate_pairing_api:init(#{}, []),

    {500, _, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    ?assertEqual(false, maps:get(<<"ok">>, Decoded)).

initiate_rejects_get() ->
    meck:expect(cowboy_req, method, fun(_Req) -> <<"GET">> end),

    {ok, _Req, _State} = initiate_pairing_api:init(#{}, []),

    {405, _, _Body} = get(last_response).

%%====================================================================
%% get_pairing_status_api tests
%%====================================================================

status_idle() ->
    meck:expect(cowboy_req, method, fun(_Req) -> <<"GET">> end),
    meck:expect(hecate_pairing, get_status, fun() -> #{status => idle} end),

    {ok, _Req, _State} = get_pairing_status_api:init(#{}, []),

    {200, _, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    ?assertEqual(true, maps:get(<<"ok">>, Decoded)),
    ?assertEqual(<<"idle">>, maps:get(<<"status">>, Decoded)).

status_pairing() ->
    meck:expect(cowboy_req, method, fun(_Req) -> <<"GET">> end),
    meck:expect(hecate_pairing, get_status, fun() ->
        #{status => pairing,
          session_id => <<"sess-123">>,
          confirm_code => <<"XYZ789">>,
          pairing_url => <<"https://macula.io/pair/sess-123">>,
          expires_in => 542}
    end),

    {ok, _Req, _State} = get_pairing_status_api:init(#{}, []),

    {200, _, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    ?assertEqual(true, maps:get(<<"ok">>, Decoded)),
    ?assertEqual(<<"pairing">>, maps:get(<<"status">>, Decoded)),
    ?assertEqual(<<"sess-123">>, maps:get(<<"session_id">>, Decoded)),
    ?assertEqual(<<"XYZ789">>, maps:get(<<"confirm_code">>, Decoded)),
    ?assertEqual(542, maps:get(<<"expires_in">>, Decoded)).

status_paired() ->
    meck:expect(cowboy_req, method, fun(_Req) -> <<"GET">> end),
    meck:expect(hecate_pairing, get_status, fun() -> #{status => paired} end),

    {ok, _Req, _State} = get_pairing_status_api:init(#{}, []),

    {200, _, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    ?assertEqual(<<"paired">>, maps:get(<<"status">>, Decoded)).

status_rejects_post() ->
    %% method is POST by default from setup
    {ok, _Req, _State} = get_pairing_status_api:init(#{}, []),

    {405, _, _Body} = get(last_response).

%%====================================================================
%% cancel_pairing_api tests
%%====================================================================

cancel_success() ->
    meck:expect(hecate_pairing, cancel, fun() -> ok end),

    {ok, _Req, _State} = cancel_pairing_api:init(#{}, []),

    {200, _, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    ?assertEqual(true, maps:get(<<"ok">>, Decoded)).

cancel_rejects_get() ->
    meck:expect(cowboy_req, method, fun(_Req) -> <<"GET">> end),

    {ok, _Req, _State} = cancel_pairing_api:init(#{}, []),

    {405, _, _Body} = get(last_response).
