-module(desk_planned_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_division_id/1, get_desk_id/1, get_desk_name/1, get_department/1,
         get_aggregate_name/1, get_description/1, get_priority/1,
         get_planned_by/1, get_planned_at/1]).

-record(desk_planned_v1, {
    division_id :: binary(),
    desk_id :: binary(),
    desk_name :: binary(),
    department :: binary(),
    aggregate_name :: binary() | undefined,
    description :: binary() | undefined,
    priority :: non_neg_integer(),
    planned_by :: binary() | undefined,
    planned_at :: non_neg_integer()
}).

new(#{division_id := DivisionId, desk_name := DeskName} = Params) ->
    #desk_planned_v1{
        division_id = DivisionId,
        desk_id = maps:get(desk_id, Params, generate_desk_id()),
        desk_name = DeskName,
        department = maps:get(department, Params, <<"CMD">>),
        aggregate_name = maps:get(aggregate_name, Params, undefined),
        description = maps:get(description, Params, undefined),
        priority = maps:get(priority, Params, 0),
        planned_by = maps:get(planned_by, Params, undefined),
        planned_at = maps:get(planned_at, Params, erlang:system_time(millisecond))
    }.

to_map(#desk_planned_v1{division_id = DI, desk_id = DId, desk_name = DN,
                         department = Dept, aggregate_name = AN, description = D,
                         priority = P, planned_by = PB, planned_at = PA}) ->
    #{
        <<"event_type">> => <<"desk_planned_v1">>,
        <<"division_id">> => DI,
        <<"desk_id">> => DId,
        <<"desk_name">> => DN,
        <<"department">> => Dept,
        <<"aggregate_name">> => AN,
        <<"description">> => D,
        <<"priority">> => P,
        <<"planned_by">> => PB,
        <<"planned_at">> => PA
    }.

from_map(Map) ->
    {ok, #desk_planned_v1{
        division_id = get_val(division_id, Map),
        desk_id = get_val(desk_id, Map),
        desk_name = get_val(desk_name, Map),
        department = get_val(department, Map),
        aggregate_name = get_val(aggregate_name, Map),
        description = get_val(description, Map),
        priority = get_val(priority, Map),
        planned_by = get_val(planned_by, Map),
        planned_at = get_val(planned_at, Map)
    }}.

get_division_id(#desk_planned_v1{division_id = V}) -> V.
get_desk_id(#desk_planned_v1{desk_id = V}) -> V.
get_desk_name(#desk_planned_v1{desk_name = V}) -> V.
get_department(#desk_planned_v1{department = V}) -> V.
get_aggregate_name(#desk_planned_v1{aggregate_name = V}) -> V.
get_description(#desk_planned_v1{description = V}) -> V.
get_priority(#desk_planned_v1{priority = V}) -> V.
get_planned_by(#desk_planned_v1{planned_by = V}) -> V.
get_planned_at(#desk_planned_v1{planned_at = V}) -> V.

generate_desk_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(4)),
    <<"desk-", Ts/binary, "-", Rand/binary>>.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
