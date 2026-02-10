-module(complete_discovery_v1).
-export([new/1, from_map/1, validate/1, to_map/1, get_venture_id/1]).

-record(complete_discovery_v1, {
    venture_id :: binary()
}).

new(#{venture_id := VentureId} = _Params) ->
    Cmd = #complete_discovery_v1{venture_id = VentureId},
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#complete_discovery_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(_) -> ok.

to_map(#complete_discovery_v1{venture_id = V}) ->
    #{<<"command_type">> => <<"complete_discovery">>, <<"venture_id">> => V}.

from_map(Map) ->
    VentureId = get_val(venture_id, Map),
    new(#{venture_id => VentureId}).

get_venture_id(#complete_discovery_v1{venture_id = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
