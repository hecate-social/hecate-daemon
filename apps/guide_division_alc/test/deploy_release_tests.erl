%%% @doc Tests for maybe_deploy_release handler and deploy_release_v1 command.
%%% Covers valid deployment with version and empty division_id rejection.
-module(deploy_release_tests).

-include_lib("eunit/include/eunit.hrl").

deploy_release_test_() ->
    [
        {"valid: handler returns event with version", fun valid_deploy_release/0},
        {"empty_division_id: command rejected",       fun empty_division_id/0}
    ].

valid_deploy_release() ->
    {ok, Cmd} = deploy_release_v1:new(#{
        division_id => <<"div-1">>,
        release_id => <<"rel-1">>,
        version => <<"0.1.0">>
    }),
    {ok, [Event]} = maybe_deploy_release:handle(Cmd),
    Map = release_deployed_v1:to_map(Event),
    ?assertEqual(<<"0.1.0">>, maps:get(<<"version">>, Map)),
    ?assertEqual(<<"rel-1">>, maps:get(<<"release_id">>, Map)),
    ?assertEqual(<<"release_deployed_v1">>, maps:get(<<"event_type">>, Map)).

empty_division_id() ->
    {ok, Cmd} = deploy_release_v1:new(#{
        division_id => <<>>,
        release_id => <<"rel-1">>,
        version => <<"0.1.0">>
    }),
    ?assertEqual({error, invalid_division_id},
                 maybe_deploy_release:handle(Cmd)).
