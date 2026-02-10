-module(generation_archived_v1).
-export([new/1, from_map/1, to_map/1, get_division_id/1, get_archived_at/1, get_archived_by/1, get_reason/1]).

-record(generation_archived_v1, {
    division_id :: binary(),
    archived_at :: non_neg_integer(),
    archived_by :: binary() | undefined,
    reason :: binary() | undefined
}).

new(#{division_id := DivisionId} = Params) ->
    #generation_archived_v1{
        division_id = DivisionId,
        archived_at = maps:get(archived_at, Params, erlang:system_time(millisecond)),
        archived_by = maps:get(archived_by, Params, undefined),
        reason = maps:get(reason, Params, undefined)
    }.

to_map(#generation_archived_v1{division_id = V, archived_at = AA, archived_by = AB, reason = R}) ->
    #{
        <<"event_type">> => <<"generation_archived_v1">>,
        <<"division_id">> => V,
        <<"archived_at">> => AA,
        <<"archived_by">> => AB,
        <<"reason">> => R
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    ArchivedAt = get_val(archived_at, Map),
    ArchivedBy = get_val(archived_by, Map),
    Reason = get_val(reason, Map),
    {ok, #generation_archived_v1{
        division_id = DivisionId,
        archived_at = ArchivedAt,
        archived_by = ArchivedBy,
        reason = Reason
    }}.

get_division_id(#generation_archived_v1{division_id = V}) -> V.
get_archived_at(#generation_archived_v1{archived_at = V}) -> V.
get_archived_by(#generation_archived_v1{archived_by = V}) -> V.
get_reason(#generation_archived_v1{reason = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
