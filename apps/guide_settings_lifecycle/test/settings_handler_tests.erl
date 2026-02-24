-module(settings_handler_tests).
-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% maybe_initiate_settings tests
%% ===================================================================

initiate_valid_test() ->
    Payload = #{linux_user => <<"rl">>, hostname => <<"host00">>,
                initiated_at => 1000},
    {ok, [Event]} = maybe_initiate_settings:handle_from_map(Payload),
    ?assertEqual(<<"settings_initiated_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"rl">>, maps:get(linux_user, Event)),
    ?assertEqual(<<"host00">>, maps:get(hostname, Event)),
    ?assertEqual(1000, maps:get(initiated_at, Event)).

initiate_empty_user_test() ->
    Payload = #{linux_user => <<>>, hostname => <<"host00">>,
                initiated_at => 1000},
    ?assertEqual({error, linux_user_required},
                 maybe_initiate_settings:handle_from_map(Payload)).

initiate_empty_hostname_test() ->
    Payload = #{linux_user => <<"rl">>, hostname => <<>>,
                initiated_at => 1000},
    ?assertEqual({error, hostname_required},
                 maybe_initiate_settings:handle_from_map(Payload)).

%% ===================================================================
%% maybe_pair_node tests
%% ===================================================================

pair_valid_test() ->
    Payload = #{github_user => <<"octocat">>, realm => <<"io.macula">>,
                paired_at => 2000},
    {ok, [Event]} = maybe_pair_node:handle_from_map(Payload),
    ?assertEqual(<<"node_paired_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"octocat">>, maps:get(github_user, Event)).

pair_empty_github_user_test() ->
    Payload = #{github_user => <<>>, realm => <<"io.macula">>,
                paired_at => 2000},
    ?assertEqual({error, github_user_required},
                 maybe_pair_node:handle_from_map(Payload)).

%% ===================================================================
%% maybe_unpair_node tests
%% ===================================================================

unpair_valid_test() ->
    Payload = #{reason => <<"manual">>, unpaired_at => 3000},
    {ok, [Event]} = maybe_unpair_node:handle_from_map(Payload),
    ?assertEqual(<<"node_unpaired_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"manual">>, maps:get(reason, Event)).

unpair_defaults_test() ->
    %% Should use defaults for reason and unpaired_at
    Payload = #{},
    {ok, [Event]} = maybe_unpair_node:handle_from_map(Payload),
    ?assertEqual(<<"node_unpaired_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"manual">>, maps:get(reason, Event)).

%% ===================================================================
%% maybe_configure_api_key tests
%% ===================================================================

configure_valid_test() ->
    Payload = #{provider => <<"openai">>, api_key => <<"sk-test123">>,
                label => <<"OpenAI">>, configured_at => 2000},
    {ok, [Event]} = maybe_configure_api_key:handle_from_map(Payload),
    ?assertEqual(<<"api_key_configured_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"openai">>, maps:get(provider, Event)),
    ?assertEqual(<<"sk-test123">>, maps:get(api_key, Event)).

configure_empty_provider_test() ->
    Payload = #{provider => <<>>, api_key => <<"sk-test">>,
                configured_at => 2000},
    ?assertEqual({error, provider_required},
                 maybe_configure_api_key:handle_from_map(Payload)).

configure_empty_api_key_test() ->
    Payload = #{provider => <<"openai">>, api_key => <<>>,
                configured_at => 2000},
    ?assertEqual({error, api_key_required},
                 maybe_configure_api_key:handle_from_map(Payload)).

%% ===================================================================
%% maybe_remove_api_key tests
%% ===================================================================

remove_valid_test() ->
    Payload = #{provider => <<"openai">>, removed_at => 3000},
    {ok, [Event]} = maybe_remove_api_key:handle_from_map(Payload),
    ?assertEqual(<<"api_key_removed_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"openai">>, maps:get(provider, Event)).

remove_empty_provider_test() ->
    Payload = #{provider => <<>>, removed_at => 3000},
    ?assertEqual({error, provider_required},
                 maybe_remove_api_key:handle_from_map(Payload)).

%% ===================================================================
%% maybe_update_preferences tests
%% ===================================================================

update_prefs_valid_test() ->
    Payload = #{preferences => #{<<"theme">> => <<"dark">>}, updated_at => 2000},
    {ok, [Event]} = maybe_update_preferences:handle_from_map(Payload),
    ?assertEqual(<<"preferences_updated_v1">>, maps:get(event_type, Event)),
    ?assertEqual(#{<<"theme">> => <<"dark">>}, maps:get(preferences, Event)).

update_prefs_not_map_test() ->
    Payload = #{preferences => <<"not a map">>, updated_at => 2000},
    ?assertEqual({error, preferences_must_be_map},
                 maybe_update_preferences:handle_from_map(Payload)).
