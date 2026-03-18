%%% @doc folder_moved_v1 event
%%% Emitted when a folder is moved to a different parent.
-module(folder_moved_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_folder_id/1, get_parent_id/1, get_moved_at/1]).

-record(folder_moved_v1, {
    folder_id :: binary(),
    parent_id :: binary() | undefined,
    moved_at  :: integer()
}).

-export_type([folder_moved_v1/0]).
-opaque folder_moved_v1() :: #folder_moved_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> folder_moved_v1().
event_type() -> folder_moved_v1.

new(#{folder_id := FolderId} = Params) ->
    #folder_moved_v1{
        folder_id = FolderId,
        parent_id = maps:get(parent_id, Params, undefined),
        moved_at  = erlang:system_time(millisecond)
    }.

-spec to_map(folder_moved_v1()) -> map().
to_map(#folder_moved_v1{} = E) ->
    Base = #{
        event_type => <<"folder_moved_v1">>,
        folder_id  => E#folder_moved_v1.folder_id,
        moved_at   => E#folder_moved_v1.moved_at
    },
    maybe_put(parent_id, E#folder_moved_v1.parent_id, Base).

-spec from_map(map()) -> {ok, folder_moved_v1()} | {error, term()}.
from_map(Map) ->
    FolderId = get_value(folder_id, Map),
    case FolderId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #folder_moved_v1{
                folder_id = FolderId,
                parent_id = get_value(parent_id, Map, undefined),
                moved_at  = get_value(moved_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_folder_id(folder_moved_v1()) -> binary().
get_folder_id(#folder_moved_v1{folder_id = V}) -> V.

-spec get_parent_id(folder_moved_v1()) -> binary() | undefined.
get_parent_id(#folder_moved_v1{parent_id = V}) -> V.

-spec get_moved_at(folder_moved_v1()) -> integer().
get_moved_at(#folder_moved_v1{moved_at = V}) -> V.

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
