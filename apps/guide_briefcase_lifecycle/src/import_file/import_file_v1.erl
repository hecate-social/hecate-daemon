%%% @doc import_file_v1 command
%%% Imports a raw file with blob data.
-module(import_file_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_file_id/1, get_name/1, get_folder_id/1, get_file_type/1,
         get_plugin/1, get_icon/1, get_blob_id/1, get_size/1, get_mime_type/1]).

-record(import_file_v1, {
    file_id   :: binary(),
    name      :: binary(),
    folder_id :: binary() | undefined,
    file_type :: binary(),
    plugin    :: binary() | undefined,
    icon      :: binary() | undefined,
    blob_id   :: binary(),
    size      :: non_neg_integer(),
    mime_type :: binary() | undefined
}).

-export_type([import_file_v1/0]).
-opaque import_file_v1() :: #import_file_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, import_file_v1()} | {error, term()}.
command_type() -> import_file_v1.

new(#{file_id := FileId, name := Name, file_type := FileType,
      blob_id := BlobId, size := Size} = Params) ->
    {ok, #import_file_v1{
        file_id   = FileId,
        name      = Name,
        folder_id = maps:get(folder_id, Params, undefined),
        file_type = FileType,
        plugin    = maps:get(plugin, Params, undefined),
        icon      = maps:get(icon, Params, undefined),
        blob_id   = BlobId,
        size      = Size,
        mime_type = maps:get(mime_type, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(import_file_v1()) -> {ok, import_file_v1()} | {error, term()}.
validate(#import_file_v1{file_id = FileId}) when
    not is_binary(FileId); byte_size(FileId) =:= 0 ->
    {error, invalid_file_id};
validate(#import_file_v1{name = Name}) when
    not is_binary(Name); byte_size(Name) =:= 0 ->
    {error, invalid_name};
validate(#import_file_v1{file_type = FileType}) when
    not is_binary(FileType); byte_size(FileType) =:= 0 ->
    {error, invalid_file_type};
validate(#import_file_v1{blob_id = BlobId}) when
    not is_binary(BlobId); byte_size(BlobId) =:= 0 ->
    {error, invalid_blob_id};
validate(#import_file_v1{size = Size}) when
    not is_integer(Size); Size < 0 ->
    {error, invalid_size};
validate(#import_file_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(import_file_v1()) -> map().
to_map(#import_file_v1{} = Cmd) ->
    Base = #{
        command_type => <<"import_file">>,
        file_id      => Cmd#import_file_v1.file_id,
        name         => Cmd#import_file_v1.name,
        file_type    => Cmd#import_file_v1.file_type,
        blob_id      => Cmd#import_file_v1.blob_id,
        size         => Cmd#import_file_v1.size
    },
    maybe_put(<<"mime_type">>, Cmd#import_file_v1.mime_type,
    maybe_put(<<"icon">>, Cmd#import_file_v1.icon,
    maybe_put(<<"plugin">>, Cmd#import_file_v1.plugin,
    maybe_put(<<"folder_id">>, Cmd#import_file_v1.folder_id, Base)))).

-spec from_map(map()) -> {ok, import_file_v1()} | {error, term()}.
from_map(Map) ->
    FileId   = get_value(file_id, Map),
    Name     = get_value(name, Map),
    FileType = get_value(file_type, Map),
    BlobId   = get_value(blob_id, Map),
    Size     = get_value(size, Map),
    case {FileId, Name, FileType, BlobId, Size} of
        {undefined, _, _, _, _} -> {error, missing_required_fields};
        {_, undefined, _, _, _} -> {error, missing_required_fields};
        {_, _, undefined, _, _} -> {error, missing_required_fields};
        {_, _, _, undefined, _} -> {error, missing_required_fields};
        {_, _, _, _, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #import_file_v1{
                file_id   = FileId,
                name      = Name,
                folder_id = get_value(folder_id, Map, undefined),
                file_type = FileType,
                plugin    = get_value(plugin, Map, undefined),
                icon      = get_value(icon, Map, undefined),
                blob_id   = BlobId,
                size      = Size,
                mime_type = get_value(mime_type, Map, undefined)
            }}
    end.

%% Accessors
-spec get_file_id(import_file_v1()) -> binary().
get_file_id(#import_file_v1{file_id = V}) -> V.

-spec get_name(import_file_v1()) -> binary().
get_name(#import_file_v1{name = V}) -> V.

-spec get_folder_id(import_file_v1()) -> binary() | undefined.
get_folder_id(#import_file_v1{folder_id = V}) -> V.

-spec get_file_type(import_file_v1()) -> binary().
get_file_type(#import_file_v1{file_type = V}) -> V.

-spec get_plugin(import_file_v1()) -> binary() | undefined.
get_plugin(#import_file_v1{plugin = V}) -> V.

-spec get_icon(import_file_v1()) -> binary() | undefined.
get_icon(#import_file_v1{icon = V}) -> V.

-spec get_blob_id(import_file_v1()) -> binary().
get_blob_id(#import_file_v1{blob_id = V}) -> V.

-spec get_size(import_file_v1()) -> non_neg_integer().
get_size(#import_file_v1{size = V}) -> V.

-spec get_mime_type(import_file_v1()) -> binary() | undefined.
get_mime_type(#import_file_v1{mime_type = V}) -> V.

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
