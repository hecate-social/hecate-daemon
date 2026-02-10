-module(design_completed_v1).
-export([new/1, from_map/1, to_map/1, get_division_id/1, get_completed_at/1]).

-record(design_completed_v1, {
    division_id :: binary(),
    completed_at :: non_neg_integer()
}).

new(#{division_id := DivisionId} = Params) ->
    #design_completed_v1{
        division_id = DivisionId,
        completed_at = maps:get(completed_at, Params, erlang:system_time(millisecond))
    }.

to_map(#design_completed_v1{division_id = V, completed_at = CA}) ->
    #{
        <<"event_type">> => <<"design_completed_v1">>,
        <<"division_id">> => V,
        <<"completed_at">> => CA
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    CompletedAt = get_val(completed_at, Map),
    {ok, #design_completed_v1{division_id = DivisionId, completed_at = CompletedAt}}.

get_division_id(#design_completed_v1{division_id = V}) -> V.
get_completed_at(#design_completed_v1{completed_at = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
