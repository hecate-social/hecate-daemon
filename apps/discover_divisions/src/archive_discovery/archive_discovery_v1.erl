-module(archive_discovery_v1).
-export([new/1, from_map/1, validate/1, to_map/1, get_venture_id/1, get_reason/1, get_archived_by/1]).

-record(archive_discovery_v1, {
    venture_id :: binary(),
    archived_by :: binary() | undefined,
    reason :: binary() | undefined
}).

new(#{venture_id := VentureId} = Params) ->
    Cmd = #archive_discovery_v1{
        venture_id = VentureId,
        archived_by = maps:get(archived_by, Params, undefined),
        reason = maps:get(reason, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#archive_discovery_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(_) -> ok.

to_map(#archive_discovery_v1{venture_id = V, archived_by = AB, reason = R}) ->
    #{<<"command_type">> => <<"archive_discovery">>, <<"venture_id">> => V,
      <<"archived_by">> => AB, <<"reason">> => R}.

from_map(Map) ->
    VentureId = get_val(venture_id, Map),
    ArchivedBy = get_val(archived_by, Map),
    Reason = get_val(reason, Map),
    new(#{venture_id => VentureId, archived_by => ArchivedBy, reason => Reason}).

get_venture_id(#archive_discovery_v1{venture_id = V}) -> V.
get_reason(#archive_discovery_v1{reason = V}) -> V.
get_archived_by(#archive_discovery_v1{archived_by = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
