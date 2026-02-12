%%% @doc Tests for initiate_division desk.
%%% Validates command creation, handler business logic, and event fields.
-module(initiate_division_tests).

-include_lib("eunit/include/eunit.hrl").

initiate_division_test_() ->
    [
        {"valid command produces one event",          fun valid/0},
        {"empty venture_id is rejected",              fun empty_venture_id/0},
        {"empty context_name is rejected",            fun empty_context_name/0},
        {"event carries correct fields",              fun event_fields/0},
        {"auto-generated id starts with division-",   fun auto_id/0}
    ].

valid() ->
    {ok, Cmd} = initiate_division_v1:new(#{
        venture_id => <<"v-1">>,
        context_name => <<"auth">>
    }),
    {ok, [_Event]} = maybe_initiate_division:handle(Cmd).

empty_venture_id() ->
    {ok, Cmd} = initiate_division_v1:new(#{
        venture_id => <<>>,
        context_name => <<"auth">>
    }),
    %% Handler validate_command rejects empty venture_id
    {error, _} = maybe_initiate_division:handle(Cmd).

empty_context_name() ->
    {ok, Cmd} = initiate_division_v1:new(#{
        venture_id => <<"v-1">>,
        context_name => <<>>
    }),
    %% Handler validate_command rejects empty context_name
    {error, _} = maybe_initiate_division:handle(Cmd).

event_fields() ->
    DivId = <<"div-test-42">>,
    {ok, Cmd} = initiate_division_v1:new(#{
        division_id => DivId,
        venture_id => <<"v-1">>,
        context_name => <<"auth">>,
        initiated_by => <<"agent@host">>
    }),
    {ok, [Event]} = maybe_initiate_division:handle(Cmd),
    Map = division_initiated_v1:to_map(Event),
    ?assertEqual(DivId,             maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"v-1">>,         maps:get(<<"venture_id">>, Map)),
    ?assertEqual(<<"auth">>,        maps:get(<<"context_name">>, Map)),
    ?assertEqual(<<"agent@host">>,  maps:get(<<"initiated_by">>, Map)),
    ?assert(is_integer(maps:get(<<"initiated_at">>, Map))).

auto_id() ->
    {ok, Cmd} = initiate_division_v1:new(#{
        venture_id => <<"v-1">>,
        context_name => <<"auth">>
    }),
    Id = initiate_division_v1:get_division_id(Cmd),
    ?assertMatch(<<"division-", _/binary>>, Id).
