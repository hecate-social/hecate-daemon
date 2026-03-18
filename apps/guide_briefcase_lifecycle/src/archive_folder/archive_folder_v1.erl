%%% @doc archive_folder_v1 command
%%% Archives a folder in the briefcase.
-module(archive_folder_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_folder_id/1]).

-record(archive_folder_v1, {
    folder_id :: binary()
}).

-export_type([archive_folder_v1/0]).
-opaque archive_folder_v1() :: #archive_folder_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, archive_folder_v1()} | {error, term()}.
command_type() -> archive_folder_v1.

new(#{folder_id := FolderId}) ->
    {ok, #archive_folder_v1{
        folder_id = FolderId
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(archive_folder_v1()) -> {ok, archive_folder_v1()} | {error, term()}.
validate(#archive_folder_v1{folder_id = FolderId}) when
    not is_binary(FolderId); byte_size(FolderId) =:= 0 ->
    {error, invalid_folder_id};
validate(#archive_folder_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(archive_folder_v1()) -> map().
to_map(#archive_folder_v1{} = Cmd) ->
    #{
        command_type => <<"archive_folder">>,
        folder_id    => Cmd#archive_folder_v1.folder_id
    }.

-spec from_map(map()) -> {ok, archive_folder_v1()} | {error, term()}.
from_map(Map) ->
    FolderId = get_value(folder_id, Map),
    case FolderId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #archive_folder_v1{
                folder_id = FolderId
            }}
    end.

%% Accessors
-spec get_folder_id(archive_folder_v1()) -> binary().
get_folder_id(#archive_folder_v1{folder_id = V}) -> V.

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
