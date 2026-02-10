-module(health_status_recorded_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_division_id/1, get_check_id/1, get_status/1,
         get_latency_ms/1, get_details/1, get_recorded_at/1]).

-record(health_status_recorded_v1, {
    division_id :: binary(),
    check_id :: binary(),
    status :: binary(),
    latency_ms :: non_neg_integer(),
    details :: binary() | undefined,
    recorded_at :: non_neg_integer()
}).

new(#{division_id := DivisionId, check_id := CheckId} = Params) ->
    #health_status_recorded_v1{
        division_id = DivisionId,
        check_id = CheckId,
        status = maps:get(status, Params, <<"unknown">>),
        latency_ms = maps:get(latency_ms, Params, 0),
        details = maps:get(details, Params, undefined),
        recorded_at = maps:get(recorded_at, Params, erlang:system_time(millisecond))
    }.

to_map(#health_status_recorded_v1{division_id = DI, check_id = CI, status = S,
                                    latency_ms = LM, details = D, recorded_at = RA}) ->
    #{
        <<"event_type">> => <<"health_status_recorded_v1">>,
        <<"division_id">> => DI,
        <<"check_id">> => CI,
        <<"status">> => S,
        <<"latency_ms">> => LM,
        <<"details">> => D,
        <<"recorded_at">> => RA
    }.

from_map(Map) ->
    {ok, #health_status_recorded_v1{
        division_id = get_val(division_id, Map),
        check_id = get_val(check_id, Map),
        status = get_val(status, Map),
        latency_ms = get_val(latency_ms, Map),
        details = get_val(details, Map),
        recorded_at = get_val(recorded_at, Map)
    }}.

get_division_id(#health_status_recorded_v1{division_id = V}) -> V.
get_check_id(#health_status_recorded_v1{check_id = V}) -> V.
get_status(#health_status_recorded_v1{status = V}) -> V.
get_latency_ms(#health_status_recorded_v1{latency_ms = V}) -> V.
get_details(#health_status_recorded_v1{details = V}) -> V.
get_recorded_at(#health_status_recorded_v1{recorded_at = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
