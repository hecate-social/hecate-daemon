-module(dependency_planned_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_division_id/1, get_dependency_id/1, get_from_desk/1, get_to_desk/1,
         get_dependency_type/1, get_description/1, get_planned_by/1, get_planned_at/1]).

-record(dependency_planned_v1, {
    division_id :: binary(),
    dependency_id :: binary(),
    from_desk :: binary(),
    to_desk :: binary(),
    dependency_type :: binary(),
    description :: binary() | undefined,
    planned_by :: binary() | undefined,
    planned_at :: non_neg_integer()
}).

new(#{division_id := DivisionId, from_desk := FromDesk,
      to_desk := ToDesk, dependency_type := DependencyType} = Params) ->
    #dependency_planned_v1{
        division_id = DivisionId,
        dependency_id = maps:get(dependency_id, Params, generate_dependency_id()),
        from_desk = FromDesk,
        to_desk = ToDesk,
        dependency_type = DependencyType,
        description = maps:get(description, Params, undefined),
        planned_by = maps:get(planned_by, Params, undefined),
        planned_at = maps:get(planned_at, Params, erlang:system_time(millisecond))
    }.

to_map(#dependency_planned_v1{division_id = DI, dependency_id = DepId, from_desk = FD,
                               to_desk = TD, dependency_type = DT, description = D,
                               planned_by = PB, planned_at = PA}) ->
    #{
        <<"event_type">> => <<"dependency_planned_v1">>,
        <<"division_id">> => DI,
        <<"dependency_id">> => DepId,
        <<"from_desk">> => FD,
        <<"to_desk">> => TD,
        <<"dependency_type">> => DT,
        <<"description">> => D,
        <<"planned_by">> => PB,
        <<"planned_at">> => PA
    }.

from_map(Map) ->
    {ok, #dependency_planned_v1{
        division_id = get_val(division_id, Map),
        dependency_id = get_val(dependency_id, Map),
        from_desk = get_val(from_desk, Map),
        to_desk = get_val(to_desk, Map),
        dependency_type = get_val(dependency_type, Map),
        description = get_val(description, Map),
        planned_by = get_val(planned_by, Map),
        planned_at = get_val(planned_at, Map)
    }}.

get_division_id(#dependency_planned_v1{division_id = V}) -> V.
get_dependency_id(#dependency_planned_v1{dependency_id = V}) -> V.
get_from_desk(#dependency_planned_v1{from_desk = V}) -> V.
get_to_desk(#dependency_planned_v1{to_desk = V}) -> V.
get_dependency_type(#dependency_planned_v1{dependency_type = V}) -> V.
get_description(#dependency_planned_v1{description = V}) -> V.
get_planned_by(#dependency_planned_v1{planned_by = V}) -> V.
get_planned_at(#dependency_planned_v1{planned_at = V}) -> V.

generate_dependency_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(4)),
    <<"dep-", Ts/binary, "-", Rand/binary>>.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
