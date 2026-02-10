-module(pause_discovery_v1).
-export([new/1, from_map/1, validate/1, to_map/1, get_venture_id/1, get_reason/1]).

-record(pause_discovery_v1, {
    venture_id :: binary(),
    reason :: binary() | undefined
}).

new(#{venture_id := VentureId} = Params) ->
    Cmd = #pause_discovery_v1{
        venture_id = VentureId,
        reason = maps:get(reason, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#pause_discovery_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(_) -> ok.

to_map(#pause_discovery_v1{venture_id = V, reason = R}) ->
    #{<<"command_type">> => <<"pause_discovery">>, <<"venture_id">> => V, <<"reason">> => R}.

from_map(Map) ->
    VentureId = get_val(venture_id, Map),
    Reason = get_val(reason, Map),
    new(#{venture_id => VentureId, reason => Reason}).

get_venture_id(#pause_discovery_v1{venture_id = V}) -> V.
get_reason(#pause_discovery_v1{reason = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
