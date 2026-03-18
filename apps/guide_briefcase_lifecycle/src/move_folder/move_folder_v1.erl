%%% @doc move_folder_v1 command
%%% Moves a folder to a different parent.
-module(move_folder_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_folder_id/1, get_parent_id/1]).

-record(move_folder_v1, {
    folder_id :: binary(),
    parent_id :: binary() | undefined
}).

-export_type([move_folder_v1/0]).
-opaque move_folder_v1() :: #move_folder_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, move_folder_v1()} | {error, term()}.
command_type() -> move_folder_v1.

new(#{folder_id := FolderId} = Params) ->
    {ok, #move_folder_v1{
        folder_id = FolderId,
        parent_id = maps:get(parent_id, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(move_folder_v1()) -> {ok, move_folder_v1()} | {error, term()}.
validate(#move_folder_v1{folder_id = FolderId}) when
    not is_binary(FolderId); byte_size(FolderId) =:= 0 ->
    {error, invalid_folder_id};
validate(#move_folder_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(move_folder_v1()) -> map().
to_map(#move_folder_v1{} = Cmd) ->
    Base = #{
        command_type => <<"move_folder">>,
        folder_id    => Cmd#move_folder_v1.folder_id
    },
    maybe_put(<<"parent_id">>, Cmd#move_folder_v1.parent_id, Base).

-spec from_map(map()) -> {ok, move_folder_v1()} | {error, term()}.
from_map(Map) ->
    FolderId = get_value(folder_id, Map),
    case FolderId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #move_folder_v1{
                folder_id = FolderId,
                parent_id = get_value(parent_id, Map, undefined)
            }}
    end.

%% Accessors
-spec get_folder_id(move_folder_v1()) -> binary().
get_folder_id(#move_folder_v1{folder_id = V}) -> V.

-spec get_parent_id(move_folder_v1()) -> binary() | undefined.
get_parent_id(#move_folder_v1{parent_id = V}) -> V.

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
