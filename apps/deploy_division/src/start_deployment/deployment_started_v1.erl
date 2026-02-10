-module(deployment_started_v1).
-export([new/1, from_map/1, to_map/1, get_division_id/1, get_started_at/1, get_started_by/1]).

-record(deployment_started_v1, {
    division_id :: binary(),
    started_at :: non_neg_integer(),
    started_by :: binary() | undefined
}).

new(#{division_id := DivisionId} = Params) ->
    #deployment_started_v1{
        division_id = DivisionId,
        started_at = maps:get(started_at, Params, erlang:system_time(millisecond)),
        started_by = maps:get(started_by, Params, undefined)
    }.

to_map(#deployment_started_v1{division_id = V, started_at = SA, started_by = SB}) ->
    #{
        <<"event_type">> => <<"deployment_started_v1">>,
        <<"division_id">> => V,
        <<"started_at">> => SA,
        <<"started_by">> => SB
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    StartedAt = get_val(started_at, Map),
    StartedBy = get_val(started_by, Map),
    {ok, #deployment_started_v1{division_id = DivisionId, started_at = StartedAt, started_by = StartedBy}}.

get_division_id(#deployment_started_v1{division_id = V}) -> V.
get_started_at(#deployment_started_v1{started_at = V}) -> V.
get_started_by(#deployment_started_v1{started_by = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
