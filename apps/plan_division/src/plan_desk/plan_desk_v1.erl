-module(plan_desk_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_desk_name/1, get_department/1,
         get_aggregate_name/1, get_description/1, get_priority/1,
         get_planned_by/1]).

-record(plan_desk_v1, {
    division_id :: binary(),
    desk_name :: binary(),
    department :: binary(),
    aggregate_name :: binary() | undefined,
    description :: binary() | undefined,
    priority :: non_neg_integer(),
    planned_by :: binary() | undefined
}).

new(#{division_id := DivisionId, desk_name := DeskName} = Params) ->
    Cmd = #plan_desk_v1{
        division_id = DivisionId,
        desk_name = DeskName,
        department = maps:get(department, Params, <<"CMD">>),
        aggregate_name = maps:get(aggregate_name, Params, undefined),
        description = maps:get(description, Params, undefined),
        priority = maps:get(priority, Params, 0),
        planned_by = maps:get(planned_by, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#plan_desk_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#plan_desk_v1{desk_name = N}) when not is_binary(N); N =:= <<>> ->
    {error, {invalid_field, desk_name}};
validate(_) -> ok.

to_map(#plan_desk_v1{division_id = DI, desk_name = DN, department = Dept,
                      aggregate_name = AN, description = D, priority = P,
                      planned_by = PB}) ->
    #{
        <<"command_type">> => <<"plan_desk">>,
        <<"division_id">> => DI,
        <<"desk_name">> => DN,
        <<"department">> => Dept,
        <<"aggregate_name">> => AN,
        <<"description">> => D,
        <<"priority">> => P,
        <<"planned_by">> => PB
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    DeskName = get_val(desk_name, Map),
    Department = get_val(department, Map),
    AggregateName = get_val(aggregate_name, Map),
    Description = get_val(description, Map),
    Priority = get_val(priority, Map),
    PlannedBy = get_val(planned_by, Map),
    new(#{division_id => DivisionId, desk_name => DeskName,
          department => Department, aggregate_name => AggregateName,
          description => Description, priority => Priority,
          planned_by => PlannedBy}).

get_division_id(#plan_desk_v1{division_id = V}) -> V.
get_desk_name(#plan_desk_v1{desk_name = V}) -> V.
get_department(#plan_desk_v1{department = V}) -> V.
get_aggregate_name(#plan_desk_v1{aggregate_name = V}) -> V.
get_description(#plan_desk_v1{description = V}) -> V.
get_priority(#plan_desk_v1{priority = V}) -> V.
get_planned_by(#plan_desk_v1{planned_by = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
