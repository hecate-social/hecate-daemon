-module(archive_design_v1).
-export([new/1, from_map/1, validate/1, to_map/1, get_division_id/1, get_archived_by/1, get_reason/1]).

-record(archive_design_v1, {
    division_id :: binary(),
    archived_by :: binary() | undefined,
    reason :: binary() | undefined
}).

new(#{division_id := DivisionId} = Params) ->
    Cmd = #archive_design_v1{
        division_id = DivisionId,
        archived_by = maps:get(archived_by, Params, undefined),
        reason = maps:get(reason, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#archive_design_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(_) -> ok.

to_map(#archive_design_v1{division_id = V, archived_by = AB, reason = R}) ->
    #{
        <<"command_type">> => <<"archive_design">>,
        <<"division_id">> => V,
        <<"archived_by">> => AB,
        <<"reason">> => R
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    ArchivedBy = get_val(archived_by, Map),
    Reason = get_val(reason, Map),
    new(#{division_id => DivisionId, archived_by => ArchivedBy, reason => Reason}).

get_division_id(#archive_design_v1{division_id = V}) -> V.
get_archived_by(#archive_design_v1{archived_by = V}) -> V.
get_reason(#archive_design_v1{reason = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
