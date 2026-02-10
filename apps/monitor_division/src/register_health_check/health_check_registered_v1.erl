-module(health_check_registered_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_division_id/1, get_check_id/1, get_check_name/1,
         get_check_type/1, get_endpoint/1, get_interval_ms/1,
         get_registered_at/1]).

-record(health_check_registered_v1, {
    division_id :: binary(),
    check_id :: binary(),
    check_name :: binary(),
    check_type :: binary(),
    endpoint :: binary(),
    interval_ms :: non_neg_integer(),
    registered_at :: non_neg_integer()
}).

new(#{division_id := DivisionId, check_name := CheckName} = Params) ->
    CheckId = maps:get(check_id, Params, generate_check_id(DivisionId, CheckName)),
    #health_check_registered_v1{
        division_id = DivisionId,
        check_id = CheckId,
        check_name = CheckName,
        check_type = maps:get(check_type, Params, <<"http">>),
        endpoint = maps:get(endpoint, Params, <<>>),
        interval_ms = maps:get(interval_ms, Params, 30000),
        registered_at = maps:get(registered_at, Params, erlang:system_time(millisecond))
    }.

to_map(#health_check_registered_v1{division_id = DI, check_id = CI, check_name = CN,
                                     check_type = CT, endpoint = EP, interval_ms = IM,
                                     registered_at = RA}) ->
    #{
        <<"event_type">> => <<"health_check_registered_v1">>,
        <<"division_id">> => DI,
        <<"check_id">> => CI,
        <<"check_name">> => CN,
        <<"check_type">> => CT,
        <<"endpoint">> => EP,
        <<"interval_ms">> => IM,
        <<"registered_at">> => RA
    }.

from_map(Map) ->
    {ok, #health_check_registered_v1{
        division_id = get_val(division_id, Map),
        check_id = get_val(check_id, Map),
        check_name = get_val(check_name, Map),
        check_type = get_val(check_type, Map),
        endpoint = get_val(endpoint, Map),
        interval_ms = get_val(interval_ms, Map),
        registered_at = get_val(registered_at, Map)
    }}.

get_division_id(#health_check_registered_v1{division_id = V}) -> V.
get_check_id(#health_check_registered_v1{check_id = V}) -> V.
get_check_name(#health_check_registered_v1{check_name = V}) -> V.
get_check_type(#health_check_registered_v1{check_type = V}) -> V.
get_endpoint(#health_check_registered_v1{endpoint = V}) -> V.
get_interval_ms(#health_check_registered_v1{interval_ms = V}) -> V.
get_registered_at(#health_check_registered_v1{registered_at = V}) -> V.

generate_check_id(DivisionId, CheckName) ->
    <<"check-", DivisionId/binary, "-", CheckName/binary>>.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
