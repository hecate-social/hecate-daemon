%%% @doc Tests for archive_division desk.
%%% Validates command creation, handler business logic, and event fields.
-module(archive_division_tests).

-include_lib("eunit/include/eunit.hrl").

archive_division_test_() ->
    [
        {"valid command produces one event",    fun valid/0},
        {"empty division_id is rejected",       fun empty_division_id/0},
        {"event carries the reason field",      fun event_reason/0}
    ].

valid() ->
    {ok, Cmd} = archive_division_v1:from_map(#{
        <<"division_id">> => <<"div-1">>,
        <<"reason">> => <<"obsolete">>
    }),
    {ok, [_Event]} = maybe_archive_division:handle(Cmd).

empty_division_id() ->
    {ok, Cmd} = archive_division_v1:from_map(#{
        <<"division_id">> => <<>>,
        <<"reason">> => <<"obsolete">>
    }),
    {error, invalid_division_id} = maybe_archive_division:handle(Cmd).

event_reason() ->
    {ok, Cmd} = archive_division_v1:from_map(#{
        <<"division_id">> => <<"div-1">>,
        <<"reason">> => <<"obsolete">>
    }),
    {ok, [Event]} = maybe_archive_division:handle(Cmd),
    Map = division_archived_v1:to_map(Event),
    ?assertEqual(<<"div-1">>,    maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"obsolete">>, maps:get(<<"reason">>, Map)),
    ?assert(is_integer(maps:get(<<"archived_at">>, Map))).
