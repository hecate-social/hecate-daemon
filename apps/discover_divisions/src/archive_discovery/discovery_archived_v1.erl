-module(discovery_archived_v1).
-export([new/1, from_map/1, to_map/1, get_venture_id/1, get_archived_at/1, get_archived_by/1, get_reason/1]).

-record(discovery_archived_v1, {
    venture_id :: binary(),
    archived_at :: non_neg_integer(),
    archived_by :: binary() | undefined,
    reason :: binary() | undefined
}).

new(#{venture_id := VentureId} = Params) ->
    #discovery_archived_v1{
        venture_id = VentureId,
        archived_at = maps:get(archived_at, Params, erlang:system_time(millisecond)),
        archived_by = maps:get(archived_by, Params, undefined),
        reason = maps:get(reason, Params, undefined)
    }.

to_map(#discovery_archived_v1{venture_id = V, archived_at = AA, archived_by = AB, reason = R}) ->
    #{<<"event_type">> => <<"discovery_archived_v1">>, <<"venture_id">> => V,
      <<"archived_at">> => AA, <<"archived_by">> => AB, <<"reason">> => R}.

from_map(Map) ->
    {ok, #discovery_archived_v1{
        venture_id = get_val(venture_id, Map),
        archived_at = get_val(archived_at, Map),
        archived_by = get_val(archived_by, Map),
        reason = get_val(reason, Map)
    }}.

get_venture_id(#discovery_archived_v1{venture_id = V}) -> V.
get_archived_at(#discovery_archived_v1{archived_at = V}) -> V.
get_archived_by(#discovery_archived_v1{archived_by = V}) -> V.
get_reason(#discovery_archived_v1{reason = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
