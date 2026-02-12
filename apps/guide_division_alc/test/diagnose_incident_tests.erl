%%% @doc Tests for maybe_diagnose_incident handler and diagnose_incident_v1 command.
%%% Covers valid diagnosis with root_cause and empty division_id rejection.
-module(diagnose_incident_tests).

-include_lib("eunit/include/eunit.hrl").

diagnose_incident_test_() ->
    [
        {"valid: handler returns event with root_cause", fun valid_diagnose_incident/0},
        {"empty_division_id: command rejected",          fun empty_division_id/0}
    ].

valid_diagnose_incident() ->
    {ok, Cmd} = diagnose_incident_v1:new(#{
        division_id => <<"div-1">>,
        diagnosis_id => <<"diag-1">>,
        incident_id => <<"inc-1">>,
        root_cause => <<"OOM">>
    }),
    {ok, [Event]} = maybe_diagnose_incident:handle(Cmd),
    Map = incident_diagnosed_v1:to_map(Event),
    ?assertEqual(<<"OOM">>, maps:get(<<"root_cause">>, Map)),
    ?assertEqual(<<"diag-1">>, maps:get(<<"diagnosis_id">>, Map)),
    ?assertEqual(<<"incident_diagnosed_v1">>, maps:get(<<"event_type">>, Map)).

empty_division_id() ->
    {ok, Cmd} = diagnose_incident_v1:new(#{
        division_id => <<>>,
        diagnosis_id => <<"diag-1">>,
        incident_id => <<"inc-1">>,
        root_cause => <<"OOM">>
    }),
    ?assertEqual({error, invalid_division_id},
                 maybe_diagnose_incident:handle(Cmd)).
