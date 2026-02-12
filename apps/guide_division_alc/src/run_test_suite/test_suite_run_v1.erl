%%% @doc test_suite_run_v1 event
-module(test_suite_run_v1).
-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_suite_id/1, get_suite_name/1, get_run_at/1]).
-record(test_suite_run_v1, {division_id :: binary(), suite_id :: binary(), suite_name :: binary(), run_at :: integer()}).
-export_type([test_suite_run_v1/0]).
-opaque test_suite_run_v1() :: #test_suite_run_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).

new(#{division_id := DivisionId, suite_id := SuiteId, suite_name := SuiteName} = _Params) ->
    #test_suite_run_v1{division_id = DivisionId, suite_id = SuiteId, suite_name = SuiteName, run_at = erlang:system_time(millisecond)}.

to_map(#test_suite_run_v1{} = E) ->
    #{<<"event_type">> => <<"test_suite_run_v1">>, <<"division_id">> => E#test_suite_run_v1.division_id,
      <<"suite_id">> => E#test_suite_run_v1.suite_id, <<"suite_name">> => E#test_suite_run_v1.suite_name,
      <<"run_at">> => E#test_suite_run_v1.run_at}.

from_map(Map) ->
    DivisionId = get_value(division_id, Map), SuiteId = get_value(suite_id, Map),
    case {DivisionId, SuiteId} of
        {undefined, _} -> {error, invalid_event}; {_, undefined} -> {error, invalid_event};
        _ -> {ok, #test_suite_run_v1{division_id = DivisionId, suite_id = SuiteId,
              suite_name = get_value(suite_name, Map, <<>>), run_at = get_value(run_at, Map, erlang:system_time(millisecond))}}
    end.

get_division_id(#test_suite_run_v1{division_id = V}) -> V.
get_suite_id(#test_suite_run_v1{suite_id = V}) -> V.
get_suite_name(#test_suite_run_v1{suite_name = V}) -> V.
get_run_at(#test_suite_run_v1{run_at = V}) -> V.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of {ok, V} -> V; error -> case maps:find(BinKey, Map) of {ok, V} -> V; error -> Default end end.
