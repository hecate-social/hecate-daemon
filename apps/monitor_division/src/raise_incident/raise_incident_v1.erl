-module(raise_incident_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_incident_title/1, get_severity/1,
         get_description/1]).

-record(raise_incident_v1, {
    division_id :: binary(),
    incident_title :: binary(),
    severity :: binary(),
    description :: binary() | undefined
}).

new(#{division_id := DivisionId, incident_title := IncidentTitle} = Params) ->
    Cmd = #raise_incident_v1{
        division_id = DivisionId,
        incident_title = IncidentTitle,
        severity = maps:get(severity, Params, <<"medium">>),
        description = maps:get(description, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#raise_incident_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#raise_incident_v1{incident_title = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, incident_title}};
validate(_) -> ok.

to_map(#raise_incident_v1{division_id = DI, incident_title = IT,
                            severity = SV, description = D}) ->
    #{
        <<"command_type">> => <<"raise_incident">>,
        <<"division_id">> => DI,
        <<"incident_title">> => IT,
        <<"severity">> => SV,
        <<"description">> => D
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    IncidentTitle = get_val(incident_title, Map),
    Severity = get_val(severity, Map),
    Description = get_val(description, Map),
    new(#{division_id => DivisionId, incident_title => IncidentTitle,
          severity => Severity, description => Description}).

get_division_id(#raise_incident_v1{division_id = V}) -> V.
get_incident_title(#raise_incident_v1{incident_title = V}) -> V.
get_severity(#raise_incident_v1{severity = V}) -> V.
get_description(#raise_incident_v1{description = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
