-module(monitoring_paused_v1).
-export([new/1, from_map/1, to_map/1, get_division_id/1, get_paused_at/1, get_reason/1]).

-record(monitoring_paused_v1, {
    division_id :: binary(),
    paused_at :: non_neg_integer(),
    reason :: binary() | undefined
}).

new(#{division_id := DivisionId} = Params) ->
    #monitoring_paused_v1{
        division_id = DivisionId,
        paused_at = maps:get(paused_at, Params, erlang:system_time(millisecond)),
        reason = maps:get(reason, Params, undefined)
    }.

to_map(#monitoring_paused_v1{division_id = V, paused_at = PA, reason = R}) ->
    #{
        <<"event_type">> => <<"monitoring_paused_v1">>,
        <<"division_id">> => V,
        <<"paused_at">> => PA,
        <<"reason">> => R
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    PausedAt = get_val(paused_at, Map),
    Reason = get_val(reason, Map),
    {ok, #monitoring_paused_v1{division_id = DivisionId, paused_at = PausedAt, reason = Reason}}.

get_division_id(#monitoring_paused_v1{division_id = V}) -> V.
get_paused_at(#monitoring_paused_v1{paused_at = V}) -> V.
get_reason(#monitoring_paused_v1{reason = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
