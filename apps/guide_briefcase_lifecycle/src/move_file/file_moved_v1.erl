%%% @doc file_moved_v1 event
%%% Emitted when a file is moved to a different folder.
-module(file_moved_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_file_id/1, get_folder_id/1, get_moved_at/1]).

-record(file_moved_v1, {
    file_id   :: binary(),
    folder_id :: binary() | undefined,
    moved_at  :: integer()
}).

-export_type([file_moved_v1/0]).
-opaque file_moved_v1() :: #file_moved_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> file_moved_v1().
event_type() -> file_moved_v1.

new(#{file_id := FileId} = Params) ->
    #file_moved_v1{
        file_id   = FileId,
        folder_id = maps:get(folder_id, Params, undefined),
        moved_at  = erlang:system_time(millisecond)
    }.

-spec to_map(file_moved_v1()) -> map().
to_map(#file_moved_v1{} = E) ->
    Base = #{
        event_type => <<"file_moved_v1">>,
        file_id    => E#file_moved_v1.file_id,
        moved_at   => E#file_moved_v1.moved_at
    },
    maybe_put(folder_id, E#file_moved_v1.folder_id, Base).

-spec from_map(map()) -> {ok, file_moved_v1()} | {error, term()}.
from_map(Map) ->
    FileId = get_value(file_id, Map),
    case FileId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #file_moved_v1{
                file_id   = FileId,
                folder_id = get_value(folder_id, Map, undefined),
                moved_at  = get_value(moved_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_file_id(file_moved_v1()) -> binary().
get_file_id(#file_moved_v1{file_id = V}) -> V.

-spec get_folder_id(file_moved_v1()) -> binary() | undefined.
get_folder_id(#file_moved_v1{folder_id = V}) -> V.

-spec get_moved_at(file_moved_v1()) -> integer().
get_moved_at(#file_moved_v1{moved_at = V}) -> V.

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
