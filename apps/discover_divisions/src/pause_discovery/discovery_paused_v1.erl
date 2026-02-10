-module(discovery_paused_v1).
-export([new/1, from_map/1, to_map/1, get_venture_id/1, get_paused_at/1, get_reason/1]).

-record(discovery_paused_v1, {
    venture_id :: binary(),
    paused_at :: non_neg_integer(),
    reason :: binary() | undefined
}).

new(#{venture_id := VentureId} = Params) ->
    #discovery_paused_v1{
        venture_id = VentureId,
        paused_at = maps:get(paused_at, Params, erlang:system_time(millisecond)),
        reason = maps:get(reason, Params, undefined)
    }.

to_map(#discovery_paused_v1{venture_id = V, paused_at = PA, reason = R}) ->
    #{<<"event_type">> => <<"discovery_paused_v1">>, <<"venture_id">> => V,
      <<"paused_at">> => PA, <<"reason">> => R}.

from_map(Map) ->
    {ok, #discovery_paused_v1{
        venture_id = get_val(venture_id, Map),
        paused_at = get_val(paused_at, Map),
        reason = get_val(reason, Map)
    }}.

get_venture_id(#discovery_paused_v1{venture_id = V}) -> V.
get_paused_at(#discovery_paused_v1{paused_at = V}) -> V.
get_reason(#discovery_paused_v1{reason = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
