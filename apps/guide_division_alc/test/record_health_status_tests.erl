%%% @doc Tests for maybe_record_health_status handler and record_health_status_v1 command.
%%% Covers valid status recording and empty division_id rejection.
-module(record_health_status_tests).

-include_lib("eunit/include/eunit.hrl").

record_health_status_test_() ->
    [
        {"valid: handler returns event with status", fun valid_record_health_status/0},
        {"empty_division_id: command rejected",      fun empty_division_id/0}
    ].

valid_record_health_status() ->
    {ok, Cmd} = record_health_status_v1:new(#{
        division_id => <<"div-1">>,
        check_id => <<"chk-1">>,
        status => <<"healthy">>
    }),
    {ok, [Event]} = maybe_record_health_status:handle(Cmd),
    Map = health_status_recorded_v1:to_map(Event),
    ?assertEqual(<<"healthy">>, maps:get(<<"status">>, Map)),
    ?assertEqual(<<"chk-1">>, maps:get(<<"check_id">>, Map)),
    ?assertEqual(<<"health_status_recorded_v1">>, maps:get(<<"event_type">>, Map)).

empty_division_id() ->
    {ok, Cmd} = record_health_status_v1:new(#{
        division_id => <<>>,
        check_id => <<"chk-1">>,
        status => <<"healthy">>
    }),
    ?assertEqual({error, invalid_division_id},
                 maybe_record_health_status:handle(Cmd)).
