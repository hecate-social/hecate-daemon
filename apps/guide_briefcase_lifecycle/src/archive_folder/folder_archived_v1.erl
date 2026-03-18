%%% @doc folder_archived_v1 event
%%% Emitted when a folder is archived.
-module(folder_archived_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_folder_id/1, get_archived_at/1]).

-record(folder_archived_v1, {
    folder_id   :: binary(),
    archived_at :: integer()
}).

-export_type([folder_archived_v1/0]).
-opaque folder_archived_v1() :: #folder_archived_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> folder_archived_v1().
event_type() -> folder_archived_v1.

new(#{folder_id := FolderId}) ->
    #folder_archived_v1{
        folder_id   = FolderId,
        archived_at = erlang:system_time(millisecond)
    }.

-spec to_map(folder_archived_v1()) -> map().
to_map(#folder_archived_v1{} = E) ->
    #{
        event_type  => <<"folder_archived_v1">>,
        folder_id   => E#folder_archived_v1.folder_id,
        archived_at => E#folder_archived_v1.archived_at
    }.

-spec from_map(map()) -> {ok, folder_archived_v1()} | {error, term()}.
from_map(Map) ->
    FolderId = get_value(folder_id, Map),
    case FolderId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #folder_archived_v1{
                folder_id   = FolderId,
                archived_at = get_value(archived_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_folder_id(folder_archived_v1()) -> binary().
get_folder_id(#folder_archived_v1{folder_id = V}) -> V.

-spec get_archived_at(folder_archived_v1()) -> integer().
get_archived_at(#folder_archived_v1{archived_at = V}) -> V.

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
