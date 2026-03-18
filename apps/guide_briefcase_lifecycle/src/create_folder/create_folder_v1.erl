%%% @doc create_folder_v1 command
%%% Creates a new folder in the briefcase.
-module(create_folder_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_folder_id/1, get_name/1, get_parent_id/1, get_icon/1]).

-record(create_folder_v1, {
    folder_id :: binary(),
    name      :: binary(),
    parent_id :: binary() | undefined,
    icon      :: binary() | undefined
}).

-export_type([create_folder_v1/0]).
-opaque create_folder_v1() :: #create_folder_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, create_folder_v1()} | {error, term()}.
command_type() -> create_folder_v1.

new(#{folder_id := FolderId, name := Name} = Params) ->
    {ok, #create_folder_v1{
        folder_id = FolderId,
        name      = Name,
        parent_id = maps:get(parent_id, Params, undefined),
        icon      = maps:get(icon, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(create_folder_v1()) -> {ok, create_folder_v1()} | {error, term()}.
validate(#create_folder_v1{folder_id = FolderId}) when
    not is_binary(FolderId); byte_size(FolderId) =:= 0 ->
    {error, invalid_folder_id};
validate(#create_folder_v1{name = Name}) when
    not is_binary(Name); byte_size(Name) =:= 0 ->
    {error, invalid_name};
validate(#create_folder_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(create_folder_v1()) -> map().
to_map(#create_folder_v1{} = Cmd) ->
    Base = #{
        command_type => <<"create_folder">>,
        folder_id    => Cmd#create_folder_v1.folder_id,
        name         => Cmd#create_folder_v1.name
    },
    maybe_put(<<"icon">>, Cmd#create_folder_v1.icon,
    maybe_put(<<"parent_id">>, Cmd#create_folder_v1.parent_id, Base)).

-spec from_map(map()) -> {ok, create_folder_v1()} | {error, term()}.
from_map(Map) ->
    FolderId = get_value(folder_id, Map),
    Name     = get_value(name, Map),
    case {FolderId, Name} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #create_folder_v1{
                folder_id = FolderId,
                name      = Name,
                parent_id = get_value(parent_id, Map, undefined),
                icon      = get_value(icon, Map, undefined)
            }}
    end.

%% Accessors
-spec get_folder_id(create_folder_v1()) -> binary().
get_folder_id(#create_folder_v1{folder_id = V}) -> V.

-spec get_name(create_folder_v1()) -> binary().
get_name(#create_folder_v1{name = V}) -> V.

-spec get_parent_id(create_folder_v1()) -> binary() | undefined.
get_parent_id(#create_folder_v1{parent_id = V}) -> V.

-spec get_icon(create_folder_v1()) -> binary() | undefined.
get_icon(#create_folder_v1{icon = V}) -> V.

%% @private Only add key to map if value is not undefined/null.
maybe_put(_Key, undefined, Map) -> Map;
maybe_put(_Key, null, Map) -> Map;
maybe_put(Key, Value, Map) -> Map#{Key => Value}.

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
