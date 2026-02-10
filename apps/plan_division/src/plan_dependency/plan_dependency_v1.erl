-module(plan_dependency_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_from_desk/1, get_to_desk/1,
         get_dependency_type/1, get_description/1, get_planned_by/1]).

-record(plan_dependency_v1, {
    division_id :: binary(),
    from_desk :: binary(),
    to_desk :: binary(),
    dependency_type :: binary(),
    description :: binary() | undefined,
    planned_by :: binary() | undefined
}).

new(#{division_id := DivisionId, from_desk := FromDesk,
      to_desk := ToDesk, dependency_type := DependencyType} = Params) ->
    Cmd = #plan_dependency_v1{
        division_id = DivisionId,
        from_desk = FromDesk,
        to_desk = ToDesk,
        dependency_type = DependencyType,
        description = maps:get(description, Params, undefined),
        planned_by = maps:get(planned_by, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#plan_dependency_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#plan_dependency_v1{from_desk = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, from_desk}};
validate(#plan_dependency_v1{to_desk = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, to_desk}};
validate(#plan_dependency_v1{dependency_type = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, dependency_type}};
validate(_) -> ok.

to_map(#plan_dependency_v1{division_id = DI, from_desk = FD, to_desk = TD,
                            dependency_type = DT, description = D, planned_by = PB}) ->
    #{
        <<"command_type">> => <<"plan_dependency">>,
        <<"division_id">> => DI,
        <<"from_desk">> => FD,
        <<"to_desk">> => TD,
        <<"dependency_type">> => DT,
        <<"description">> => D,
        <<"planned_by">> => PB
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    FromDesk = get_val(from_desk, Map),
    ToDesk = get_val(to_desk, Map),
    DependencyType = get_val(dependency_type, Map),
    Description = get_val(description, Map),
    PlannedBy = get_val(planned_by, Map),
    new(#{division_id => DivisionId, from_desk => FromDesk,
          to_desk => ToDesk, dependency_type => DependencyType,
          description => Description, planned_by => PlannedBy}).

get_division_id(#plan_dependency_v1{division_id = V}) -> V.
get_from_desk(#plan_dependency_v1{from_desk = V}) -> V.
get_to_desk(#plan_dependency_v1{to_desk = V}) -> V.
get_dependency_type(#plan_dependency_v1{dependency_type = V}) -> V.
get_description(#plan_dependency_v1{description = V}) -> V.
get_planned_by(#plan_dependency_v1{planned_by = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
