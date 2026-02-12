%%% @doc dependency_planned_v1 event
-module(dependency_planned_v1).
-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_dependency_id/1, get_from_desk/1, get_to_desk/1, get_dep_type/1, get_planned_at/1]).

-record(dependency_planned_v1, {
    division_id   :: binary(),
    dependency_id :: binary(),
    from_desk     :: binary(),
    to_desk       :: binary(),
    dep_type      :: binary() | undefined,
    planned_at    :: integer()
}).

-export_type([dependency_planned_v1/0]).
-opaque dependency_planned_v1() :: #dependency_planned_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> dependency_planned_v1().
new(#{division_id := DivisionId, dependency_id := DepId, from_desk := FromDesk, to_desk := ToDesk} = Params) ->
    #dependency_planned_v1{
        division_id = DivisionId,
        dependency_id = DepId,
        from_desk = FromDesk,
        to_desk = ToDesk,
        dep_type = maps:get(dep_type, Params, undefined),
        planned_at = erlang:system_time(millisecond)
    }.

-spec to_map(dependency_planned_v1()) -> map().
to_map(#dependency_planned_v1{} = E) ->
    #{
        <<"event_type">> => <<"dependency_planned_v1">>,
        <<"division_id">> => E#dependency_planned_v1.division_id,
        <<"dependency_id">> => E#dependency_planned_v1.dependency_id,
        <<"from_desk">> => E#dependency_planned_v1.from_desk,
        <<"to_desk">> => E#dependency_planned_v1.to_desk,
        <<"dep_type">> => E#dependency_planned_v1.dep_type,
        <<"planned_at">> => E#dependency_planned_v1.planned_at
    }.

-spec from_map(map()) -> {ok, dependency_planned_v1()} | {error, term()}.
from_map(Map) ->
    DivisionId = get_value(division_id, Map),
    DepId = get_value(dependency_id, Map),
    case {DivisionId, DepId} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ ->
            {ok, #dependency_planned_v1{
                division_id = DivisionId,
                dependency_id = DepId,
                from_desk = get_value(from_desk, Map),
                to_desk = get_value(to_desk, Map),
                dep_type = get_value(dep_type, Map, undefined),
                planned_at = get_value(planned_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_division_id(dependency_planned_v1()) -> binary().
get_division_id(#dependency_planned_v1{division_id = V}) -> V.
-spec get_dependency_id(dependency_planned_v1()) -> binary().
get_dependency_id(#dependency_planned_v1{dependency_id = V}) -> V.
-spec get_from_desk(dependency_planned_v1()) -> binary().
get_from_desk(#dependency_planned_v1{from_desk = V}) -> V.
-spec get_to_desk(dependency_planned_v1()) -> binary().
get_to_desk(#dependency_planned_v1{to_desk = V}) -> V.
-spec get_dep_type(dependency_planned_v1()) -> binary() | undefined.
get_dep_type(#dependency_planned_v1{dep_type = V}) -> V.
-spec get_planned_at(dependency_planned_v1()) -> integer().
get_planned_at(#dependency_planned_v1{planned_at = V}) -> V.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> case maps:find(BinKey, Map) of {ok, V} -> V; error -> Default end
    end.
