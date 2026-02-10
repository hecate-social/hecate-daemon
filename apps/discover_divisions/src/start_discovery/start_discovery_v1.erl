-module(start_discovery_v1).
-export([new/1, from_map/1, validate/1, to_map/1, get_venture_id/1]).

-record(start_discovery_v1, {
    venture_id :: binary(),
    started_by :: binary() | undefined
}).

new(#{venture_id := VentureId} = Params) ->
    Cmd = #start_discovery_v1{
        venture_id = VentureId,
        started_by = maps:get(started_by, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#start_discovery_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(_) -> ok.

to_map(#start_discovery_v1{venture_id = V, started_by = SB}) ->
    #{
        <<"command_type">> => <<"start_discovery">>,
        <<"venture_id">> => V,
        <<"started_by">> => SB
    }.

from_map(Map) ->
    VentureId = get_val(venture_id, Map),
    StartedBy = get_val(started_by, Map),
    new(#{venture_id => VentureId, started_by => StartedBy}).

get_venture_id(#start_discovery_v1{venture_id = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
