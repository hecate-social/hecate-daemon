%%% @doc Tests for maybe_raise_incident handler and raise_incident_v1 command.
%%% Covers valid incident raising with severity and empty division_id rejection.
-module(raise_incident_tests).

-include_lib("eunit/include/eunit.hrl").

raise_incident_test_() ->
    [
        {"valid: handler returns event with severity", fun valid_raise_incident/0},
        {"empty_division_id: command rejected",        fun empty_division_id/0}
    ].

valid_raise_incident() ->
    {ok, Cmd} = raise_incident_v1:new(#{
        division_id => <<"div-1">>,
        incident_id => <<"inc-1">>,
        title => <<"API down">>,
        severity => <<"critical">>
    }),
    {ok, [Event]} = maybe_raise_incident:handle(Cmd),
    Map = incident_raised_v1:to_map(Event),
    ?assertEqual(<<"critical">>, maps:get(<<"severity">>, Map)),
    ?assertEqual(<<"inc-1">>, maps:get(<<"incident_id">>, Map)),
    ?assertEqual(<<"incident_raised_v1">>, maps:get(<<"event_type">>, Map)).

empty_division_id() ->
    {ok, Cmd} = raise_incident_v1:new(#{
        division_id => <<>>,
        incident_id => <<"inc-1">>,
        title => <<"API down">>,
        severity => <<"critical">>
    }),
    ?assertEqual({error, invalid_division_id},
                 maybe_raise_incident:handle(Cmd)).
