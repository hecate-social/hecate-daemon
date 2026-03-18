%%% @doc folder_renamed_v1 event
%%% Emitted when a folder is renamed.
-module(folder_renamed_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_folder_id/1, get_name/1, get_renamed_at/1]).

-record(folder_renamed_v1, {
    folder_id  :: binary(),
    name       :: binary(),
    renamed_at :: integer()
}).

-export_type([folder_renamed_v1/0]).
-opaque folder_renamed_v1() :: #folder_renamed_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> folder_renamed_v1().
event_type() -> folder_renamed_v1.

new(#{folder_id := FolderId, name := Name}) ->
    #folder_renamed_v1{
        folder_id  = FolderId,
        name       = Name,
        renamed_at = erlang:system_time(millisecond)
    }.

-spec to_map(folder_renamed_v1()) -> map().
to_map(#folder_renamed_v1{} = E) ->
    #{
        event_type => <<"folder_renamed_v1">>,
        folder_id  => E#folder_renamed_v1.folder_id,
        name       => E#folder_renamed_v1.name,
        renamed_at => E#folder_renamed_v1.renamed_at
    }.

-spec from_map(map()) -> {ok, folder_renamed_v1()} | {error, term()}.
from_map(Map) ->
    FolderId = get_value(folder_id, Map),
    Name     = get_value(name, Map),
    case {FolderId, Name} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ ->
            {ok, #folder_renamed_v1{
                folder_id  = FolderId,
                name       = Name,
                renamed_at = get_value(renamed_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_folder_id(folder_renamed_v1()) -> binary().
get_folder_id(#folder_renamed_v1{folder_id = V}) -> V.

-spec get_name(folder_renamed_v1()) -> binary().
get_name(#folder_renamed_v1{name = V}) -> V.

-spec get_renamed_at(folder_renamed_v1()) -> integer().
get_renamed_at(#folder_renamed_v1{renamed_at = V}) -> V.

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
