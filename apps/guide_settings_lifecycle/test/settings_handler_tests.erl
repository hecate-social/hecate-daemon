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
