-module(rescue_started_v1).
-export([new/1, from_map/1, to_map/1, get_division_id/1, get_incident_id/1, get_started_at/1, get_started_by/1]).

-record(rescue_started_v1, {
    division_id :: binary(),
    incident_id :: binary(),
    started_at :: non_neg_integer(),
    started_by :: binary() | undefined
}).

new(#{division_id := DivisionId, incident_id := IncidentId} = Params) ->
    #rescue_started_v1{
        division_id = DivisionId,
        incident_id = IncidentId,
        started_at = maps:get(started_at, Params, erlang:system_time(millisecond)),
        started_by = maps:get(started_by, Params, undefined)
    }.

to_map(#rescue_started_v1{division_id = DI, incident_id = II, started_at = SA, started_by = SB}) ->
    #{
        <<"event_type">> => <<"rescue_started_v1">>,
        <<"division_id">> => DI,
        <<"incident_id">> => II,
        <<"started_at">> => SA,
        <<"started_by">> => SB
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    IncidentId = get_val(incident_id, Map),
    StartedAt = get_val(started_at, Map),
    StartedBy = get_val(started_by, Map),
    {ok, #rescue_started_v1{
        division_id = DivisionId,
        incident_id = IncidentId,
        started_at = StartedAt,
        started_by = StartedBy
    }}.

get_division_id(#rescue_started_v1{division_id = V}) -> V.
get_incident_id(#rescue_started_v1{incident_id = V}) -> V.
get_started_at(#rescue_started_v1{started_at = V}) -> V.
get_started_by(#rescue_started_v1{started_by = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
