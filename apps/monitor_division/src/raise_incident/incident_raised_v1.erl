-module(incident_raised_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_division_id/1, get_incident_id/1, get_incident_title/1,
         get_severity/1, get_description/1, get_raised_at/1]).

-record(incident_raised_v1, {
    division_id :: binary(),
    incident_id :: binary(),
    incident_title :: binary(),
    severity :: binary(),
    description :: binary() | undefined,
    raised_at :: non_neg_integer()
}).

new(#{division_id := DivisionId, incident_title := IncidentTitle} = Params) ->
    RaisedAt = maps:get(raised_at, Params, erlang:system_time(millisecond)),
    IncidentId = maps:get(incident_id, Params, generate_incident_id(DivisionId, RaisedAt)),
    #incident_raised_v1{
        division_id = DivisionId,
        incident_id = IncidentId,
        incident_title = IncidentTitle,
        severity = maps:get(severity, Params, <<"medium">>),
        description = maps:get(description, Params, undefined),
        raised_at = RaisedAt
    }.

to_map(#incident_raised_v1{division_id = DI, incident_id = II, incident_title = IT,
                             severity = SV, description = D, raised_at = RA}) ->
    #{
        <<"event_type">> => <<"incident_raised_v1">>,
        <<"division_id">> => DI,
        <<"incident_id">> => II,
        <<"incident_title">> => IT,
        <<"severity">> => SV,
        <<"description">> => D,
        <<"raised_at">> => RA
    }.

from_map(Map) ->
    {ok, #incident_raised_v1{
        division_id = get_val(division_id, Map),
        incident_id = get_val(incident_id, Map),
        incident_title = get_val(incident_title, Map),
        severity = get_val(severity, Map),
        description = get_val(description, Map),
        raised_at = get_val(raised_at, Map)
    }}.

get_division_id(#incident_raised_v1{division_id = V}) -> V.
get_incident_id(#incident_raised_v1{incident_id = V}) -> V.
get_incident_title(#incident_raised_v1{incident_title = V}) -> V.
get_severity(#incident_raised_v1{severity = V}) -> V.
get_description(#incident_raised_v1{description = V}) -> V.
get_raised_at(#incident_raised_v1{raised_at = V}) -> V.

generate_incident_id(DivisionId, Timestamp) ->
    <<"inc-", DivisionId/binary, "-", (integer_to_binary(Timestamp))/binary>>.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
