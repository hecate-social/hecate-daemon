%%% @doc file_archived_v1 event
%%% Emitted when a file is archived.
-module(file_archived_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_file_id/1, get_archived_at/1]).

-record(file_archived_v1, {
    file_id     :: binary(),
    archived_at :: integer()
}).

-export_type([file_archived_v1/0]).
-opaque file_archived_v1() :: #file_archived_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> file_archived_v1().
event_type() -> file_archived_v1.

new(#{file_id := FileId}) ->
    #file_archived_v1{
        file_id     = FileId,
        archived_at = erlang:system_time(millisecond)
    }.

-spec to_map(file_archived_v1()) -> map().
to_map(#file_archived_v1{} = E) ->
    #{
        event_type  => <<"file_archived_v1">>,
        file_id     => E#file_archived_v1.file_id,
        archived_at => E#file_archived_v1.archived_at
    }.

-spec from_map(map()) -> {ok, file_archived_v1()} | {error, term()}.
from_map(Map) ->
    FileId = get_value(file_id, Map),
    case FileId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #file_archived_v1{
                file_id     = FileId,
                archived_at = get_value(archived_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_file_id(file_archived_v1()) -> binary().
get_file_id(#file_archived_v1{file_id = V}) -> V.

-spec get_archived_at(file_archived_v1()) -> integer().
get_archived_at(#file_archived_v1{archived_at = V}) -> V.

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
