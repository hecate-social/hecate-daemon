-module(hecate_admin_auth_tests).
-include_lib("eunit/include/eunit.hrl").

%% Cowboy_req is hard to construct directly in tests; mock the
%% functions we use (header/2, the response helpers indirectly via
%% hecate_api_utils). We use meck on cowboy_req + hecate_api_utils
%% to capture status codes.

setup() ->
    meck:new(cowboy_req, [passthrough, non_strict]),
    meck:new(hecate_api_utils, [passthrough]),
    meck:expect(hecate_api_utils, json_error,
                fun(Status, Reason, _Req) ->
                    erlang:put(last_error, {Status, Reason}),
                    fake_req
                end),
    application:unset_env(hecate, admin_token),
    os:unsetenv("HECATE_ADMIN_TOKEN"),
    erlang:erase(last_error),
    ok.

cleanup(_) ->
    meck:unload(cowboy_req),
    meck:unload(hecate_api_utils),
    application:unset_env(hecate, admin_token),
    os:unsetenv("HECATE_ADMIN_TOKEN"),
    ok.

auth_test_() ->
    {foreach,
     fun setup/0,
     fun cleanup/1,
     [fun denies_when_no_token_configured/1,
      fun accepts_matching_token/1,
      fun rejects_wrong_token/1,
      fun rejects_missing_authorization/1,
      fun rejects_bad_scheme/1]}.

denies_when_no_token_configured(_) ->
    fun() ->
        meck:expect(cowboy_req, header, fun(_, _) -> undefined end),
        ?assertMatch({error, admin_disabled, _},
                     hecate_admin_auth:authorise(fake_req)),
        ?assertMatch({503, _}, erlang:get(last_error))
    end.

accepts_matching_token(_) ->
    fun() ->
        application:set_env(hecate, admin_token, <<"sek1">>),
        meck:expect(cowboy_req, header,
                    fun(<<"authorization">>, _) -> <<"Bearer sek1">> end),
        ?assertEqual(ok, hecate_admin_auth:authorise(fake_req))
    end.

rejects_wrong_token(_) ->
    fun() ->
        application:set_env(hecate, admin_token, <<"sek1">>),
        meck:expect(cowboy_req, header,
                    fun(<<"authorization">>, _) -> <<"Bearer wrong">> end),
        ?assertMatch({error, unauthorized, _},
                     hecate_admin_auth:authorise(fake_req)),
        {Status, Reason} = erlang:get(last_error),
        ?assertEqual(401, Status),
        ?assertEqual(<<"invalid_token">>, Reason)
    end.

rejects_missing_authorization(_) ->
    fun() ->
        application:set_env(hecate, admin_token, <<"sek1">>),
        meck:expect(cowboy_req, header, fun(_, _) -> undefined end),
        ?assertMatch({error, unauthorized, _},
                     hecate_admin_auth:authorise(fake_req)),
        {401, <<"missing_authorization">>} = erlang:get(last_error)
    end.

rejects_bad_scheme(_) ->
    fun() ->
        application:set_env(hecate, admin_token, <<"sek1">>),
        meck:expect(cowboy_req, header,
                    fun(_, _) -> <<"Basic c2VrMQ==">> end),
        ?assertMatch({error, unauthorized, _},
                     hecate_admin_auth:authorise(fake_req)),
        {401, <<"bad_authorization_scheme">>} = erlang:get(last_error)
    end.
