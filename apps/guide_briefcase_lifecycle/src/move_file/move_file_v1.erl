%%% @doc move_file_v1 command
%%% Moves a file to a different folder.
-module(move_file_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_file_id/1, get_folder_id/1]).

-record(move_file_v1, {
    file_id   :: binary(),
    folder_id :: binary() | undefined
}).

-export_type([move_file_v1/0]).
-opaque move_file_v1() :: #move_file_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, move_file_v1()} | {error, term()}.
command_type() -> move_file_v1.

new(#{file_id := FileId} = Params) ->
    {ok, #move_file_v1{
        file_id   = FileId,
        folder_id = maps:get(folder_id, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(move_file_v1()) -> {ok, move_file_v1()} | {error, term()}.
validate(#move_file_v1{file_id = FileId}) when
    not is_binary(FileId); byte_size(FileId) =:= 0 ->
    {error, invalid_file_id};
validate(#move_file_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(move_file_v1()) -> map().
to_map(#move_file_v1{} = Cmd) ->
    Base = #{
        command_type => <<"move_file">>,
        file_id      => Cmd#move_file_v1.file_id
    },
    maybe_put(<<"folder_id">>, Cmd#move_file_v1.folder_id, Base).

-spec from_map(map()) -> {ok, move_file_v1()} | {error, term()}.
from_map(Map) ->
    FileId = get_value(file_id, Map),
    case FileId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #move_file_v1{
                file_id   = FileId,
                folder_id = get_value(folder_id, Map, undefined)
            }}
    end.

%% Accessors
-spec get_file_id(move_file_v1()) -> binary().
get_file_id(#move_file_v1{file_id = V}) -> V.

-spec get_folder_id(move_file_v1()) -> binary() | undefined.
get_folder_id(#move_file_v1{folder_id = V}) -> V.

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
