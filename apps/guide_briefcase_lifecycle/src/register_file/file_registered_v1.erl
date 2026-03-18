%%% @doc file_registered_v1 event
%%% Emitted when a plugin creates a new file (no blob).
-module(file_registered_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_file_id/1, get_name/1, get_folder_id/1, get_file_type/1,
         get_plugin/1, get_icon/1, get_created_at/1]).

-record(file_registered_v1, {
    file_id    :: binary(),
    name       :: binary(),
    folder_id  :: binary() | undefined,
    file_type  :: binary(),
    plugin     :: binary() | undefined,
    icon       :: binary() | undefined,
    created_at :: integer()
}).

-export_type([file_registered_v1/0]).
-opaque file_registered_v1() :: #file_registered_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> file_registered_v1().
event_type() -> file_registered_v1.

new(#{file_id := FileId, name := Name, file_type := FileType} = Params) ->
    #file_registered_v1{
        file_id    = FileId,
        name       = Name,
        folder_id  = maps:get(folder_id, Params, undefined),
        file_type  = FileType,
        plugin     = maps:get(plugin, Params, undefined),
        icon       = maps:get(icon, Params, undefined),
        created_at = erlang:system_time(millisecond)
    }.

-spec to_map(file_registered_v1()) -> map().
to_map(#file_registered_v1{} = E) ->
    Base = #{
        event_type => <<"file_registered_v1">>,
        file_id    => E#file_registered_v1.file_id,
        name       => E#file_registered_v1.name,
        file_type  => E#file_registered_v1.file_type,
        created_at => E#file_registered_v1.created_at
    },
    maybe_put(icon, E#file_registered_v1.icon,
    maybe_put(plugin, E#file_registered_v1.plugin,
    maybe_put(folder_id, E#file_registered_v1.folder_id, Base))).

-spec from_map(map()) -> {ok, file_registered_v1()} | {error, term()}.
from_map(Map) ->
    FileId   = get_value(file_id, Map),
    Name     = get_value(name, Map),
    FileType = get_value(file_type, Map),
    case {FileId, Name, FileType} of
        {undefined, _, _} -> {error, invalid_event};
        {_, undefined, _} -> {error, invalid_event};
        {_, _, undefined} -> {error, invalid_event};
        _ ->
            {ok, #file_registered_v1{
                file_id    = FileId,
                name       = Name,
                folder_id  = get_value(folder_id, Map, undefined),
                file_type  = FileType,
                plugin     = get_value(plugin, Map, undefined),
                icon       = get_value(icon, Map, undefined),
                created_at = get_value(created_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_file_id(file_registered_v1()) -> binary().
get_file_id(#file_registered_v1{file_id = V}) -> V.

-spec get_name(file_registered_v1()) -> binary().
get_name(#file_registered_v1{name = V}) -> V.

-spec get_folder_id(file_registered_v1()) -> binary() | undefined.
get_folder_id(#file_registered_v1{folder_id = V}) -> V.

-spec get_file_type(file_registered_v1()) -> binary().
get_file_type(#file_registered_v1{file_type = V}) -> V.

-spec get_plugin(file_registered_v1()) -> binary() | undefined.
get_plugin(#file_registered_v1{plugin = V}) -> V.

-spec get_icon(file_registered_v1()) -> binary() | undefined.
get_icon(#file_registered_v1{icon = V}) -> V.

-spec get_created_at(file_registered_v1()) -> integer().
get_created_at(#file_registered_v1{created_at = V}) -> V.

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
