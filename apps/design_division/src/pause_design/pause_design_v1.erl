-module(pause_design_v1).
-export([new/1, from_map/1, validate/1, to_map/1, get_division_id/1, get_reason/1]).

-record(pause_design_v1, {
    division_id :: binary(),
    reason :: binary() | undefined
}).

new(#{division_id := DivisionId} = Params) ->
    Cmd = #pause_design_v1{
        division_id = DivisionId,
        reason = maps:get(reason, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#pause_design_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(_) -> ok.

to_map(#pause_design_v1{division_id = V, reason = R}) ->
    #{
        <<"command_type">> => <<"pause_design">>,
        <<"division_id">> => V,
        <<"reason">> => R
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    Reason = get_val(reason, Map),
    new(#{division_id => DivisionId, reason => Reason}).

get_division_id(#pause_design_v1{division_id = V}) -> V.
get_reason(#pause_design_v1{reason = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
