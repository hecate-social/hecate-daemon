%%% @doc reorganize_launcher_v1 command
%%% Full layout update: reorder groups, move entries, rename groups, change icons.
-module(reorganize_launcher_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_groups/1]).

-record(reorganize_launcher_v1, {
    groups :: [map()]
}).

-export_type([reorganize_launcher_v1/0]).
-opaque reorganize_launcher_v1() :: #reorganize_launcher_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, reorganize_launcher_v1()} | {error, term()}.
new(#{groups := Groups}) when is_list(Groups) ->
    {ok, #reorganize_launcher_v1{
        groups = Groups
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(reorganize_launcher_v1()) -> {ok, reorganize_launcher_v1()} | {error, term()}.
validate(#reorganize_launcher_v1{groups = Groups}) when not is_list(Groups) ->
    {error, invalid_groups};
validate(#reorganize_launcher_v1{groups = Groups} = Cmd) ->
    case validate_groups(Groups) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

-spec to_map(reorganize_launcher_v1()) -> map().
to_map(#reorganize_launcher_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"reorganize_launcher">>,
        <<"groups">>       => Cmd#reorganize_launcher_v1.groups
    }.

-spec from_map(map()) -> {ok, reorganize_launcher_v1()} | {error, term()}.
from_map(Map) ->
    Groups = get_value(groups, Map),
    case Groups of
        undefined -> {error, missing_required_fields};
        _ when is_list(Groups) ->
            {ok, #reorganize_launcher_v1{
                groups = Groups
            }};
        _ -> {error, invalid_groups}
    end.

%% Accessors
-spec get_groups(reorganize_launcher_v1()) -> [map()].
get_groups(#reorganize_launcher_v1{groups = V}) -> V.

%% Internal

validate_groups([]) -> ok;
validate_groups([G | Rest]) when is_map(G) ->
    Name = maps:get(name, G, maps:get(<<"name">>, G, undefined)),
    Apps = maps:get(apps, G, maps:get(<<"apps">>, G, undefined)),
    case {Name, Apps} of
        {undefined, _} -> {error, group_missing_name};
        {_, undefined} -> {error, group_missing_apps};
        {_, _} when not is_list(Apps) -> {error, group_apps_not_list};
        _ -> validate_groups(Rest)
    end;
validate_groups([_ | _]) ->
    {error, group_not_map}.

%% Internal helper to get value with atom or binary key
get_value(Key, Map) ->
    get_value(Key, Map, undefined).

get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> Default
            end
    end.
