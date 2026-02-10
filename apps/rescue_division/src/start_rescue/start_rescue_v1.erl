-module(start_rescue_v1).
-export([new/1, from_map/1, validate/1, to_map/1, get_division_id/1, get_incident_id/1, get_started_by/1]).

-record(start_rescue_v1, {
    division_id :: binary(),
    incident_id :: binary(),
    started_by :: binary() | undefined
}).

new(#{division_id := DivisionId, incident_id := IncidentId} = Params) ->
    Cmd = #start_rescue_v1{
        division_id = DivisionId,
        incident_id = IncidentId,
        started_by = maps:get(started_by, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#start_rescue_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#start_rescue_v1{incident_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, incident_id}};
validate(_) -> ok.

to_map(#start_rescue_v1{division_id = DI, incident_id = II, started_by = SB}) ->
    #{
        <<"command_type">> => <<"start_rescue">>,
        <<"division_id">> => DI,
        <<"incident_id">> => II,
        <<"started_by">> => SB
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    IncidentId = get_val(incident_id, Map),
    StartedBy = get_val(started_by, Map),
    new(#{division_id => DivisionId, incident_id => IncidentId, started_by => StartedBy}).

get_division_id(#start_rescue_v1{division_id = V}) -> V.
get_incident_id(#start_rescue_v1{incident_id = V}) -> V.
get_started_by(#start_rescue_v1{started_by = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
