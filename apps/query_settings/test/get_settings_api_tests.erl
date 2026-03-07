%%%-------------------------------------------------------------------
%%% @doc Tests for get_settings_api handler.
%%% @end
%%%-------------------------------------------------------------------
-module(get_settings_api_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Test Descriptions
%%====================================================================

get_settings_api_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"returns structured identity and preferences", fun returns_structured_response/0},
            {"returns 404 when settings not initialized", fun returns_404_not_initialized/0},
            {"decodes preferences from ETS", fun decodes_preferences/0},
            {"rejects non-GET methods", fun rejects_non_get/0},
            {"includes realm memberships in response", fun includes_realm_memberships/0}
        ]
    }.

%%====================================================================
%% Setup / Cleanup
%%====================================================================

setup() ->
    meck:new(project_settings_store, [non_strict]),
    meck:new(project_realm_memberships_store, [non_strict]),
    meck:new(cowboy_req, [passthrough]),
    meck:expect(cowboy_req, reply, fun(Status, Headers, Body, Req) ->
        put(last_response, {Status, Headers, Body}),
        Req
    end),
    meck:expect(cowboy_req, method, fun(_Req) -> <<"GET">> end),
    %% Default: no realms
    meck:expect(project_realm_memberships_store, list_confirmed, fun() -> {ok, []} end),
    ok.

cleanup(_) ->
    meck:unload(project_settings_store),
    meck:unload(project_realm_memberships_store),
    meck:unload(cowboy_req),
    erase(last_response),
    ok.

%%====================================================================
%% Test Cases
%%====================================================================

returns_structured_response() ->
    mock_settings(<<"rl">>, <<"host00">>, <<"usr-1">>, #{}, 0, 1000),

    {ok, _Req, _State} = get_settings_api:init(#{}, []),

    {200, _, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),

    ?assertEqual(true, maps:get(<<"ok">>, Decoded)),
    ?assert(maps:is_key(<<"identity">>, Decoded)),
    ?assert(maps:is_key(<<"preferences">>, Decoded)),
    ?assert(maps:is_key(<<"realms">>, Decoded)),

    Identity = maps:get(<<"identity">>, Decoded),
    ?assertEqual(<<"usr-1">>, maps:get(<<"hecate_user_id">>, Identity)),
    ?assertEqual(<<"rl">>, maps:get(<<"linux_user">>, Identity)),
    ?assertEqual(<<"host00">>, maps:get(<<"hostname">>, Identity)),
    ?assertEqual(1000, maps:get(<<"initiated_at">>, Identity)),
    ?assertEqual(0, maps:get(<<"status">>, Identity)),

    Realms = maps:get(<<"realms">>, Decoded),
    ?assertEqual([], Realms).

returns_404_not_initialized() ->
    meck:expect(project_settings_store, get, fun() -> {error, not_found} end),

    {ok, _Req, _State} = get_settings_api:init(#{}, []),

    {404, _, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    ?assertEqual(false, maps:get(<<"ok">>, Decoded)).

decodes_preferences() ->
    Prefs = #{<<"theme">> => <<"dark">>, <<"lang">> => <<"en">>},
    mock_settings(<<"rl">>, <<"host00">>, <<"usr-1">>, Prefs, 0, 1000),

    {ok, _Req, _State} = get_settings_api:init(#{}, []),

    {200, _, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    DecodedPrefs = maps:get(<<"preferences">>, Decoded),
    ?assertEqual(<<"dark">>, maps:get(<<"theme">>, DecodedPrefs)),
    ?assertEqual(<<"en">>, maps:get(<<"lang">>, DecodedPrefs)).

rejects_non_get() ->
    meck:expect(cowboy_req, method, fun(_Req) -> <<"POST">> end),

    {ok, _Req, _State} = get_settings_api:init(#{}, []),

    {405, _, _Body} = get(last_response).

includes_realm_memberships() ->
    mock_settings(<<"rl">>, <<"host00">>, <<"usr-1">>, #{}, 0, 1000),
    meck:expect(project_realm_memberships_store, list_confirmed, fun() ->
        {ok, [#{membership_id => <<"mem-1">>, realm_id => <<"io.macula">>,
                realm_url => <<"https://macula.io">>,
                oauth_account => <<"octocat">>, oauth_provider => <<"github">>,
                confirmed_at => 2000}]}
    end),

    {ok, _Req, _State} = get_settings_api:init(#{}, []),

    {200, _, Body} = get(last_response),
    Decoded = json:decode(iolist_to_binary(Body)),
    Realms = maps:get(<<"realms">>, Decoded),
    ?assertEqual(1, length(Realms)),
    [Realm] = Realms,
    ?assertEqual(<<"mem-1">>, maps:get(<<"membership_id">>, Realm)),
    ?assertEqual(<<"io.macula">>, maps:get(<<"realm_id">>, Realm)),
    ?assertEqual(<<"octocat">>, maps:get(<<"oauth_account">>, Realm)),
    ?assertEqual(<<"github">>, maps:get(<<"oauth_provider">>, Realm)),
    ?assertEqual(2000, maps:get(<<"confirmed_at">>, Realm)).

%%====================================================================
%% Helpers
%%====================================================================

mock_settings(LinuxUser, Hostname, HecateUserId, Prefs, Status, InitiatedAt) ->
    meck:expect(project_settings_store, get, fun() ->
        {ok, #{linux_user => LinuxUser, hostname => Hostname,
               hecate_user_id => HecateUserId, preferences => Prefs,
               status => Status, initiated_at => InitiatedAt}}
    end).
