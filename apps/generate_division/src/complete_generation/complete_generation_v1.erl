-module(complete_generation_v1).
-export([new/1, from_map/1, validate/1, to_map/1, get_division_id/1]).

-record(complete_generation_v1, {
    division_id :: binary()
}).

new(#{division_id := DivisionId}) ->
    Cmd = #complete_generation_v1{
        division_id = DivisionId
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#complete_generation_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(_) -> ok.

to_map(#complete_generation_v1{division_id = V}) ->
    #{
        <<"command_type">> => <<"complete_generation">>,
        <<"division_id">> => V
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    new(#{division_id => DivisionId}).

get_division_id(#complete_generation_v1{division_id = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
