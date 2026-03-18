%%% @doc rename_file_v1 command
%%% Renames an existing file.
-module(rename_file_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_file_id/1, get_name/1]).

-record(rename_file_v1, {
    file_id :: binary(),
    name    :: binary()
}).

-export_type([rename_file_v1/0]).
-opaque rename_file_v1() :: #rename_file_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, rename_file_v1()} | {error, term()}.
command_type() -> rename_file_v1.

new(#{file_id := FileId, name := Name}) ->
    {ok, #rename_file_v1{
        file_id = FileId,
        name    = Name
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(rename_file_v1()) -> {ok, rename_file_v1()} | {error, term()}.
validate(#rename_file_v1{file_id = FileId}) when
    not is_binary(FileId); byte_size(FileId) =:= 0 ->
    {error, invalid_file_id};
validate(#rename_file_v1{name = Name}) when
    not is_binary(Name); byte_size(Name) =:= 0 ->
    {error, invalid_name};
validate(#rename_file_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(rename_file_v1()) -> map().
to_map(#rename_file_v1{} = Cmd) ->
    #{
        command_type => <<"rename_file">>,
        file_id      => Cmd#rename_file_v1.file_id,
        name         => Cmd#rename_file_v1.name
    }.

-spec from_map(map()) -> {ok, rename_file_v1()} | {error, term()}.
from_map(Map) ->
    FileId = get_value(file_id, Map),
    Name   = get_value(name, Map),
    case {FileId, Name} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #rename_file_v1{
                file_id = FileId,
                name    = Name
            }}
    end.

%% Accessors
-spec get_file_id(rename_file_v1()) -> binary().
get_file_id(#rename_file_v1{file_id = V}) -> V.

-spec get_name(rename_file_v1()) -> binary().
get_name(#rename_file_v1{name = V}) -> V.

%% Internal helper to get value with atom or binary key
get_value(Key, Map) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> undefined
            end
    end.
