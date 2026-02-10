-module(register_health_check_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_check_name/1, get_check_type/1,
         get_endpoint/1, get_interval_ms/1]).

-record(register_health_check_v1, {
    division_id :: binary(),
    check_name :: binary(),
    check_type :: binary(),
    endpoint :: binary(),
    interval_ms :: non_neg_integer()
}).

new(#{division_id := DivisionId, check_name := CheckName} = Params) ->
    Cmd = #register_health_check_v1{
        division_id = DivisionId,
        check_name = CheckName,
        check_type = maps:get(check_type, Params, <<"http">>),
        endpoint = maps:get(endpoint, Params, <<>>),
        interval_ms = maps:get(interval_ms, Params, 30000)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#register_health_check_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#register_health_check_v1{check_name = N}) when not is_binary(N); N =:= <<>> ->
    {error, {invalid_field, check_name}};
validate(_) -> ok.

to_map(#register_health_check_v1{division_id = DI, check_name = CN, check_type = CT,
                                   endpoint = EP, interval_ms = IM}) ->
    #{
        <<"command_type">> => <<"register_health_check">>,
        <<"division_id">> => DI,
        <<"check_name">> => CN,
        <<"check_type">> => CT,
        <<"endpoint">> => EP,
        <<"interval_ms">> => IM
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    CheckName = get_val(check_name, Map),
    CheckType = get_val(check_type, Map),
    Endpoint = get_val(endpoint, Map),
    IntervalMs = get_val(interval_ms, Map),
    new(#{division_id => DivisionId, check_name => CheckName,
          check_type => CheckType, endpoint => Endpoint,
          interval_ms => IntervalMs}).

get_division_id(#register_health_check_v1{division_id = V}) -> V.
get_check_name(#register_health_check_v1{check_name = V}) -> V.
get_check_type(#register_health_check_v1{check_type = V}) -> V.
get_endpoint(#register_health_check_v1{endpoint = V}) -> V.
get_interval_ms(#register_health_check_v1{interval_ms = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
