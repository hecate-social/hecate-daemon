-module(settings_aggregate_tests).
-include_lib("eunit/include/eunit.hrl").

-include("settings_status.hrl").

%% ===================================================================
%% Execute tests
%% ===================================================================

initiate_happy_test() ->
    State = settings_state:new(<<>>),
    Payload = #{
        command_type => initiate_settings,
        linux_user => <<"rl">>,
        hostname => <<"host00">>,
        initiated_at => 1000
    },
    {ok, [Event]} = settings_aggregate:execute(State, Payload),
    ?assertEqual(<<"settings_initiated_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"rl">>, maps:get(linux_user, Event)),
    ?assertEqual(<<"host00">>, maps:get(hostname, Event)).

initiate_already_test() ->
    State0 = settings_state:new(<<>>),
    Event = #{event_type => <<"settings_initiated_v1">>,
              linux_user => <<"rl">>, hostname => <<"host00">>,
              initiated_at => 1000},
    State1 = settings_aggregate:apply(State0, Event),
    Payload = #{command_type => initiate_settings, linux_user => <<"rl">>,
                hostname => <<"host00">>, initiated_at => 2000},
    ?assertEqual({error, already_initiated}, settings_aggregate:execute(State1, Payload)).

update_preferences_happy_test() ->
    State = initiated_state(),
    Payload = #{command_type => update_preferences,
                preferences => #{<<"theme">> => <<"dark">>}, updated_at => 2000},
    {ok, [Event]} = settings_aggregate:execute(State, Payload),
    ?assertEqual(<<"preferences_updated_v1">>, maps:get(event_type, Event)).

update_preferences_not_initiated_test() ->
    State = settings_state:new(<<>>),
    Payload = #{command_type => update_preferences,
                preferences => #{<<"theme">> => <<"dark">>}, updated_at => 2000},
    ?assertEqual({error, not_initiated}, settings_aggregate:execute(State, Payload)).

unknown_command_test() ->
    State = settings_state:new(<<>>),
    ?assertEqual({error, unknown_command},
                 settings_aggregate:execute(State, #{command_type => bogus})).

%% ===================================================================
%% Apply event tests
%% ===================================================================

apply_initiated_test() ->
    State0 = settings_state:new(<<>>),
    Event = #{event_type => <<"settings_initiated_v1">>,
              linux_user => <<"rl">>, hostname => <<"host00">>,
              initiated_at => 1000},
    State1 = settings_aggregate:apply(State0, Event),
    %% Verify via execute — update_preferences should work now
    Payload = #{command_type => update_preferences,
                preferences => #{<<"a">> => 1}, updated_at => 2000},
    {ok, _} = settings_aggregate:execute(State1, Payload).

apply_preferences_updated_test() ->
    State0 = initiated_state(),
    Evt1 = #{event_type => <<"preferences_updated_v1">>,
             preferences => #{<<"theme">> => <<"dark">>}, updated_at => 2000},
    State1 = settings_aggregate:apply(State0, Evt1),
    Evt2 = #{event_type => <<"preferences_updated_v1">>,
             preferences => #{<<"lang">> => <<"en">>}, updated_at => 3000},
    State2 = settings_aggregate:apply(State1, Evt2),
    Payload = #{command_type => update_preferences,
                preferences => #{<<"test">> => true}, updated_at => 4000},
    {ok, _} = settings_aggregate:execute(State2, Payload).

apply_unknown_event_test() ->
    State0 = settings_state:new(<<>>),
    Event = #{event_type => <<"bogus_event_v1">>, data => <<"foo">>},
    State1 = settings_aggregate:apply(State0, Event),
    ?assertEqual(State0, State1).

%% Old pairing events are silently ignored (backward read compat)
apply_old_paired_event_ignored_test() ->
    State0 = initiated_state(),
    Event = #{event_type => <<"node_paired_v1">>,
              github_user => <<"octocat">>, realm => <<"io.macula">>,
              paired_at => 2000},
    State1 = settings_aggregate:apply(State0, Event),
    ?assertEqual(State0, State1).

apply_old_unpaired_event_ignored_test() ->
    State0 = initiated_state(),
    Event = #{event_type => <<"node_unpaired_v1">>,
              reason => <<"manual">>, unpaired_at => 3000},
    State1 = settings_aggregate:apply(State0, Event),
    ?assertEqual(State0, State1).

%% ===================================================================
%% Roundtrip tests
%% ===================================================================

roundtrip_preferences_merge_test() ->
    S0 = initiated_state(),
    {ok, [E1]} = settings_aggregate:execute(S0, #{command_type => update_preferences,
        preferences => #{<<"theme">> => <<"dark">>, <<"lang">> => <<"en">>},
        updated_at => 2000}),
    S1 = settings_aggregate:apply(S0, E1),
    {ok, [E2]} = settings_aggregate:execute(S1, #{command_type => update_preferences,
        preferences => #{<<"theme">> => <<"light">>}, updated_at => 3000}),
    S2 = settings_aggregate:apply(S1, E2),
    {ok, _} = settings_aggregate:execute(S2, #{command_type => update_preferences,
        preferences => #{<<"font">> => <<"mono">>}, updated_at => 4000}).

%% ===================================================================
%% Helpers
%% ===================================================================

initiated_state() ->
    S0 = settings_state:new(<<>>),
    Event = #{event_type => <<"settings_initiated_v1">>,
              linux_user => <<"rl">>, hostname => <<"host00">>,
              initiated_at => 1000},
    settings_aggregate:apply(S0, Event).
