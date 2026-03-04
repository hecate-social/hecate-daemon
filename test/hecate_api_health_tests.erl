%%%-------------------------------------------------------------------
%%% @doc Tests for hecate_api_health handler.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_health_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Test Descriptions
%%====================================================================

health_api_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"returns healthy status when identity initialized", fun healthy_initialized/0},
            {"returns not_initialized when no identity", fun healthy_not_initialized/0},
            {"includes uptime in response", fun includes_uptime/0}
        ]
    }.

%%====================================================================
%% Setup / Cleanup
%%====================================================================

setup() ->
    %% Mock dependencies
    meck:new(hecate_identity, [passthrough]),
    meck:new(cowboy_req, [passthrough]),
    
    %% Mock cowboy_req:reply to capture response
    meck:expect(cowboy_req, reply, fun(Status, Headers, Body, Req) ->
        %% Store response in process dictionary for test verification
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

healthy_initialized() ->
    meck:expect(hecate_identity, is_initialized, fun() -> true end),
    
    Req = #{},
    {ok, _Req2, _State} = hecate_api_health:init(Req, []),
    
    {200, _Headers, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    
    ?assertEqual(<<"healthy">>, maps:get(<<"status">>, Decoded)),
    ?assertEqual(<<"initialized">>, maps:get(<<"identity">>, Decoded)).

healthy_not_initialized() ->
    meck:expect(hecate_identity, is_initialized, fun() -> false end),
    
    Req = #{},
    {ok, _Req2, _State} = hecate_api_health:init(Req, []),
    
    {200, _Headers, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    
    ?assertEqual(<<"healthy">>, maps:get(<<"status">>, Decoded)),
    ?assertEqual(<<"not_initialized">>, maps:get(<<"identity">>, Decoded)).

includes_uptime() ->
    meck:expect(hecate_identity, is_initialized, fun() -> true end),
    
    Req = #{},
    {ok, _Req2, _State} = hecate_api_health:init(Req, []),
    
    {200, _Headers, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    
    ?assert(maps:is_key(<<"uptime_seconds">>, Decoded)),
    Uptime = maps:get(<<"uptime_seconds">>, Decoded),
    ?assert(is_integer(Uptime)),
    ?assert(Uptime >= 0).
