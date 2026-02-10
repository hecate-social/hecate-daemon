-module(discovery_completed_v1).
-export([new/1, from_map/1, to_map/1, get_venture_id/1, get_completed_at/1]).

-record(discovery_completed_v1, {
    venture_id :: binary(),
    completed_at :: non_neg_integer()
}).

new(#{venture_id := VentureId} = Params) ->
    #discovery_completed_v1{
        venture_id = VentureId,
        completed_at = maps:get(completed_at, Params, erlang:system_time(millisecond))
    }.

to_map(#discovery_completed_v1{venture_id = V, completed_at = CA}) ->
    #{<<"event_type">> => <<"discovery_completed_v1">>, <<"venture_id">> => V, <<"completed_at">> => CA}.

from_map(Map) ->
    {ok, #discovery_completed_v1{
        venture_id = get_val(venture_id, Map),
        completed_at = get_val(completed_at, Map)
    }}.

get_venture_id(#discovery_completed_v1{venture_id = V}) -> V.
get_completed_at(#discovery_completed_v1{completed_at = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
