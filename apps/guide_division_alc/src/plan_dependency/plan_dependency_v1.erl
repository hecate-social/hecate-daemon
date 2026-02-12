%%% @doc plan_dependency_v1 command
%%% Plans a dependency between desks within a division (AnP phase).
-module(plan_dependency_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_dependency_id/1, get_from_desk/1, get_to_desk/1, get_dep_type/1]).
-export([generate_id/0]).

-record(plan_dependency_v1, {
    division_id   :: binary(),
    dependency_id :: binary(),
    from_desk     :: binary(),
    to_desk       :: binary(),
    dep_type      :: binary() | undefined
}).

-export_type([plan_dependency_v1/0]).
-opaque plan_dependency_v1() :: #plan_dependency_v1{}.
-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, plan_dependency_v1()} | {error, term()}.
new(#{division_id := DivisionId, from_desk := FromDesk, to_desk := ToDesk} = Params) ->
    DepId = maps:get(dependency_id, Params, generate_id()),
    {ok, #plan_dependency_v1{
        division_id = DivisionId,
        dependency_id = DepId,
        from_desk = FromDesk,
        to_desk = ToDesk,
        dep_type = maps:get(dep_type, Params, undefined)
    }};
new(_) -> {error, missing_required_fields}.

-spec validate(plan_dependency_v1()) -> {ok, plan_dependency_v1()} | {error, term()}.
validate(#plan_dependency_v1{division_id = V}) when not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_division_id};
validate(#plan_dependency_v1{from_desk = F}) when not is_binary(F); byte_size(F) =:= 0 ->
    {error, invalid_from_desk};
validate(#plan_dependency_v1{to_desk = T}) when not is_binary(T); byte_size(T) =:= 0 ->
    {error, invalid_to_desk};
validate(#plan_dependency_v1{} = Cmd) -> {ok, Cmd}.

-spec to_map(plan_dependency_v1()) -> map().
to_map(#plan_dependency_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"plan_dependency">>,
        <<"division_id">> => Cmd#plan_dependency_v1.division_id,
        <<"dependency_id">> => Cmd#plan_dependency_v1.dependency_id,
        <<"from_desk">> => Cmd#plan_dependency_v1.from_desk,
        <<"to_desk">> => Cmd#plan_dependency_v1.to_desk,
        <<"dep_type">> => Cmd#plan_dependency_v1.dep_type
    }.

-spec from_map(map()) -> {ok, plan_dependency_v1()} | {error, term()}.
from_map(Map) ->
    DivisionId = get_value(division_id, Map),
    FromDesk = get_value(from_desk, Map),
    ToDesk = get_value(to_desk, Map),
    case {DivisionId, FromDesk, ToDesk} of
        {undefined, _, _} -> {error, missing_required_fields};
        {_, undefined, _} -> {error, missing_required_fields};
        {_, _, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #plan_dependency_v1{
                division_id = DivisionId,
                dependency_id = get_value(dependency_id, Map, generate_id()),
                from_desk = FromDesk,
                to_desk = ToDesk,
                dep_type = get_value(dep_type, Map, undefined)
            }}
    end.

-spec get_division_id(plan_dependency_v1()) -> binary().
get_division_id(#plan_dependency_v1{division_id = V}) -> V.
-spec get_dependency_id(plan_dependency_v1()) -> binary().
get_dependency_id(#plan_dependency_v1{dependency_id = V}) -> V.
-spec get_from_desk(plan_dependency_v1()) -> binary().
get_from_desk(#plan_dependency_v1{from_desk = V}) -> V.
-spec get_to_desk(plan_dependency_v1()) -> binary().
get_to_desk(#plan_dependency_v1{to_desk = V}) -> V.
-spec get_dep_type(plan_dependency_v1()) -> binary() | undefined.
get_dep_type(#plan_dependency_v1{dep_type = V}) -> V.

-spec generate_id() -> binary().
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(4)),
    <<"dep-", Ts/binary, "-", Rand/binary>>.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> case maps:find(BinKey, Map) of {ok, V} -> V; error -> Default end
    end.
