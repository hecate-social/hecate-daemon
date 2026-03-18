%%% @doc star_file_v1 command
%%% Stars a file for quick access.
-module(star_file_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_file_id/1]).

-record(star_file_v1, {
    file_id :: binary()
}).

-export_type([star_file_v1/0]).
-opaque star_file_v1() :: #star_file_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, star_file_v1()} | {error, term()}.
command_type() -> star_file_v1.

new(#{file_id := FileId}) ->
    {ok, #star_file_v1{
        file_id = FileId
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(star_file_v1()) -> {ok, star_file_v1()} | {error, term()}.
validate(#star_file_v1{file_id = FileId}) when
    not is_binary(FileId); byte_size(FileId) =:= 0 ->
    {error, invalid_file_id};
validate(#star_file_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(star_file_v1()) -> map().
to_map(#star_file_v1{} = Cmd) ->
    #{
        command_type => <<"star_file">>,
        file_id      => Cmd#star_file_v1.file_id
    }.

-spec from_map(map()) -> {ok, star_file_v1()} | {error, term()}.
from_map(Map) ->
    FileId = get_value(file_id, Map),
    case FileId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #star_file_v1{
                file_id = FileId
            }}
    end.

%% Accessors
-spec get_file_id(star_file_v1()) -> binary().
get_file_id(#star_file_v1{file_id = V}) -> V.

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
