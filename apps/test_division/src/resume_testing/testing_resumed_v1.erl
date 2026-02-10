-module(testing_resumed_v1).
-export([new/1, from_map/1, to_map/1, get_division_id/1, get_resumed_at/1]).

-record(testing_resumed_v1, {
    division_id :: binary(),
    resumed_at :: non_neg_integer()
}).

new(#{division_id := DivisionId} = Params) ->
    #testing_resumed_v1{
        division_id = DivisionId,
        resumed_at = maps:get(resumed_at, Params, erlang:system_time(millisecond))
    }.

to_map(#testing_resumed_v1{division_id = V, resumed_at = RA}) ->
    #{
        <<"event_type">> => <<"testing_resumed_v1">>,
        <<"division_id">> => V,
        <<"resumed_at">> => RA
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    ResumedAt = get_val(resumed_at, Map),
    {ok, #testing_resumed_v1{division_id = DivisionId, resumed_at = ResumedAt}}.

get_division_id(#testing_resumed_v1{division_id = V}) -> V.
get_resumed_at(#testing_resumed_v1{resumed_at = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
