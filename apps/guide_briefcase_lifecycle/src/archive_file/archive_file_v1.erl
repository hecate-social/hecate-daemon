%%% @doc archive_file_v1 command
%%% Archives a file in the briefcase.
-module(archive_file_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_file_id/1]).

-record(archive_file_v1, {
    file_id :: binary()
}).

-export_type([archive_file_v1/0]).
-opaque archive_file_v1() :: #archive_file_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, archive_file_v1()} | {error, term()}.
command_type() -> archive_file_v1.

new(#{file_id := FileId}) ->
    {ok, #archive_file_v1{
        file_id = FileId
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(archive_file_v1()) -> {ok, archive_file_v1()} | {error, term()}.
validate(#archive_file_v1{file_id = FileId}) when
    not is_binary(FileId); byte_size(FileId) =:= 0 ->
    {error, invalid_file_id};
validate(#archive_file_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(archive_file_v1()) -> map().
to_map(#archive_file_v1{} = Cmd) ->
    #{
        command_type => <<"archive_file">>,
        file_id      => Cmd#archive_file_v1.file_id
    }.

-spec from_map(map()) -> {ok, archive_file_v1()} | {error, term()}.
from_map(Map) ->
    FileId = get_value(file_id, Map),
    case FileId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #archive_file_v1{
                file_id = FileId
            }}
    end.

%% Accessors
-spec get_file_id(archive_file_v1()) -> binary().
get_file_id(#archive_file_v1{file_id = V}) -> V.

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
