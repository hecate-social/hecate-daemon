%%% @doc register_file_v1 command
%%% Registers a new file created by a plugin (no blob).
-module(register_file_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_file_id/1, get_name/1, get_folder_id/1, get_file_type/1,
         get_plugin/1, get_icon/1]).

-record(register_file_v1, {
    file_id   :: binary(),
    name      :: binary(),
    folder_id :: binary() | undefined,
    file_type :: binary(),
    plugin    :: binary() | undefined,
    icon      :: binary() | undefined
}).

-export_type([register_file_v1/0]).
-opaque register_file_v1() :: #register_file_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, register_file_v1()} | {error, term()}.
command_type() -> register_file_v1.

new(#{file_id := FileId, name := Name, file_type := FileType} = Params) ->
    {ok, #register_file_v1{
        file_id   = FileId,
        name      = Name,
        folder_id = maps:get(folder_id, Params, undefined),
        file_type = FileType,
        plugin    = maps:get(plugin, Params, undefined),
        icon      = maps:get(icon, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(register_file_v1()) -> {ok, register_file_v1()} | {error, term()}.
validate(#register_file_v1{file_id = FileId}) when
    not is_binary(FileId); byte_size(FileId) =:= 0 ->
    {error, invalid_file_id};
validate(#register_file_v1{name = Name}) when
    not is_binary(Name); byte_size(Name) =:= 0 ->
    {error, invalid_name};
validate(#register_file_v1{file_type = FileType}) when
    not is_binary(FileType); byte_size(FileType) =:= 0 ->
    {error, invalid_file_type};
validate(#register_file_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(register_file_v1()) -> map().
to_map(#register_file_v1{} = Cmd) ->
    Base = #{
        command_type => <<"register_file">>,
        file_id      => Cmd#register_file_v1.file_id,
        name         => Cmd#register_file_v1.name,
        file_type    => Cmd#register_file_v1.file_type
    },
    maybe_put(<<"icon">>, Cmd#register_file_v1.icon,
    maybe_put(<<"plugin">>, Cmd#register_file_v1.plugin,
    maybe_put(<<"folder_id">>, Cmd#register_file_v1.folder_id, Base))).

-spec from_map(map()) -> {ok, register_file_v1()} | {error, term()}.
from_map(Map) ->
    FileId   = get_value(file_id, Map),
    Name     = get_value(name, Map),
    FileType = get_value(file_type, Map),
    case {FileId, Name, FileType} of
        {undefined, _, _} -> {error, missing_required_fields};
        {_, undefined, _} -> {error, missing_required_fields};
        {_, _, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #register_file_v1{
                file_id   = FileId,
                name      = Name,
                folder_id = get_value(folder_id, Map, undefined),
                file_type = FileType,
                plugin    = get_value(plugin, Map, undefined),
                icon      = get_value(icon, Map, undefined)
            }}
    end.

%% Accessors
-spec get_file_id(register_file_v1()) -> binary().
get_file_id(#register_file_v1{file_id = V}) -> V.

-spec get_name(register_file_v1()) -> binary().
get_name(#register_file_v1{name = V}) -> V.

-spec get_folder_id(register_file_v1()) -> binary() | undefined.
get_folder_id(#register_file_v1{folder_id = V}) -> V.

-spec get_file_type(register_file_v1()) -> binary().
get_file_type(#register_file_v1{file_type = V}) -> V.

-spec get_plugin(register_file_v1()) -> binary() | undefined.
get_plugin(#register_file_v1{plugin = V}) -> V.

-spec get_icon(register_file_v1()) -> binary() | undefined.
get_icon(#register_file_v1{icon = V}) -> V.

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
