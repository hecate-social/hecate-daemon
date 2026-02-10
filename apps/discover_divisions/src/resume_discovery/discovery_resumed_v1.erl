-module(discovery_resumed_v1).
-export([new/1, from_map/1, to_map/1, get_venture_id/1, get_resumed_at/1]).

-record(discovery_resumed_v1, {
    venture_id :: binary(),
    resumed_at :: non_neg_integer()
}).

new(#{venture_id := VentureId} = Params) ->
    #discovery_resumed_v1{
        venture_id = VentureId,
        resumed_at = maps:get(resumed_at, Params, erlang:system_time(millisecond))
    }.

to_map(#discovery_resumed_v1{venture_id = V, resumed_at = RA}) ->
    #{<<"event_type">> => <<"discovery_resumed_v1">>, <<"venture_id">> => V, <<"resumed_at">> => RA}.

from_map(Map) ->
    {ok, #discovery_resumed_v1{
        venture_id = get_val(venture_id, Map),
        resumed_at = get_val(resumed_at, Map)
    }}.

get_venture_id(#discovery_resumed_v1{venture_id = V}) -> V.
get_resumed_at(#discovery_resumed_v1{resumed_at = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
