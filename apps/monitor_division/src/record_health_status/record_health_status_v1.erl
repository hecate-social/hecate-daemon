-module(record_health_status_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_check_id/1, get_status/1,
         get_latency_ms/1, get_details/1]).

-record(record_health_status_v1, {
    division_id :: binary(),
    check_id :: binary(),
    status :: binary(),
    latency_ms :: non_neg_integer(),
    details :: binary() | undefined
}).

new(#{division_id := DivisionId, check_id := CheckId} = Params) ->
    Cmd = #record_health_status_v1{
        division_id = DivisionId,
        check_id = CheckId,
        status = maps:get(status, Params, <<"unknown">>),
        latency_ms = maps:get(latency_ms, Params, 0),
        details = maps:get(details, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#record_health_status_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#record_health_status_v1{check_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, check_id}};
validate(_) -> ok.

to_map(#record_health_status_v1{division_id = DI, check_id = CI, status = S,
                                  latency_ms = LM, details = D}) ->
    #{
        <<"command_type">> => <<"record_health_status">>,
        <<"division_id">> => DI,
        <<"check_id">> => CI,
        <<"status">> => S,
        <<"latency_ms">> => LM,
        <<"details">> => D
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    CheckId = get_val(check_id, Map),
    Status = get_val(status, Map),
    LatencyMs = get_val(latency_ms, Map),
    Details = get_val(details, Map),
    new(#{division_id => DivisionId, check_id => CheckId,
          status => Status, latency_ms => LatencyMs,
          details => Details}).

get_division_id(#record_health_status_v1{division_id = V}) -> V.
get_check_id(#record_health_status_v1{check_id = V}) -> V.
get_status(#record_health_status_v1{status = V}) -> V.
get_latency_ms(#record_health_status_v1{latency_ms = V}) -> V.
get_details(#record_health_status_v1{details = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
