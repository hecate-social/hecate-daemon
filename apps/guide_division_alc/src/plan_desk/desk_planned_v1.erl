%%% @doc desk_planned_v1 event
%%% Emitted when a desk is planned within a division.
-module(desk_planned_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_desk_name/1, get_description/1,
         get_department/1, get_commands/1, get_planned_at/1]).

-record(desk_planned_v1, {
    division_id :: binary(),
    desk_name   :: binary(),
    description :: binary() | undefined,
    department  :: binary() | undefined,
    commands    :: list() | undefined,
    planned_at  :: integer()
}).

-export_type([desk_planned_v1/0]).
-opaque desk_planned_v1() :: #desk_planned_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> desk_planned_v1().
new(#{division_id := DivisionId, desk_name := DeskName} = Params) ->
    #desk_planned_v1{
        division_id = DivisionId,
        desk_name = DeskName,
        description = maps:get(description, Params, undefined),
        department = maps:get(department, Params, undefined),
        commands = maps:get(commands, Params, undefined),
        planned_at = erlang:system_time(millisecond)
    }.

-spec to_map(desk_planned_v1()) -> map().
to_map(#desk_planned_v1{} = E) ->
    #{
        <<"event_type">> => <<"desk_planned_v1">>,
        <<"division_id">> => E#desk_planned_v1.division_id,
        <<"desk_name">> => E#desk_planned_v1.desk_name,
        <<"description">> => E#desk_planned_v1.description,
        <<"department">> => E#desk_planned_v1.department,
        <<"commands">> => E#desk_planned_v1.commands,
        <<"planned_at">> => E#desk_planned_v1.planned_at
    }.

-spec from_map(map()) -> {ok, desk_planned_v1()} | {error, term()}.
from_map(Map) ->
    DivisionId = get_value(division_id, Map),
    DeskName = get_value(desk_name, Map),
    case {DivisionId, DeskName} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ ->
            {ok, #desk_planned_v1{
                division_id = DivisionId,
                desk_name = DeskName,
                description = get_value(description, Map, undefined),
                department = get_value(department, Map, undefined),
                commands = get_value(commands, Map, undefined),
                planned_at = get_value(planned_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_division_id(desk_planned_v1()) -> binary().
get_division_id(#desk_planned_v1{division_id = V}) -> V.
-spec get_desk_name(desk_planned_v1()) -> binary().
get_desk_name(#desk_planned_v1{desk_name = V}) -> V.
-spec get_description(desk_planned_v1()) -> binary() | undefined.
get_description(#desk_planned_v1{description = V}) -> V.
-spec get_department(desk_planned_v1()) -> binary() | undefined.
get_department(#desk_planned_v1{department = V}) -> V.
-spec get_commands(desk_planned_v1()) -> list() | undefined.
get_commands(#desk_planned_v1{commands = V}) -> V.
-spec get_planned_at(desk_planned_v1()) -> integer().
get_planned_at(#desk_planned_v1{planned_at = V}) -> V.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> case maps:find(BinKey, Map) of {ok, V} -> V; error -> Default end
    end.
