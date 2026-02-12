%%% @doc Tests for maybe_register_health_check handler and register_health_check_v1 command.
%%% Covers valid health check registration and empty division_id rejection.
-module(register_health_check_tests).

-include_lib("eunit/include/eunit.hrl").

register_health_check_test_() ->
    [
        {"valid: handler returns event with check details", fun valid_register_health_check/0},
        {"empty_division_id: command rejected",             fun empty_division_id/0}
    ].

valid_register_health_check() ->
    {ok, Cmd} = register_health_check_v1:new(#{
        division_id => <<"div-1">>,
        check_id => <<"chk-1">>,
        check_name => <<"api_health">>,
        check_type => <<"http">>
    }),
    {ok, [Event]} = maybe_register_health_check:handle(Cmd),
    Map = health_check_registered_v1:to_map(Event),
    ?assertEqual(<<"chk-1">>, maps:get(<<"check_id">>, Map)),
    ?assertEqual(<<"api_health">>, maps:get(<<"check_name">>, Map)),
    ?assertEqual(<<"health_check_registered_v1">>, maps:get(<<"event_type">>, Map)).

empty_division_id() ->
    {ok, Cmd} = register_health_check_v1:new(#{
        division_id => <<>>,
        check_id => <<"chk-1">>,
        check_name => <<"api_health">>,
        check_type => <<"http">>
    }),
    ?assertEqual({error, invalid_division_id},
                 maybe_register_health_check:handle(Cmd)).
