%%% @doc folder_initiated_v1 event
%%% Emitted when a new folder is created in the briefcase.
-module(folder_initiated_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_folder_id/1, get_name/1, get_parent_id/1, get_icon/1, get_created_at/1]).

-record(folder_initiated_v1, {
    folder_id  :: binary(),
    name       :: binary(),
    parent_id  :: binary() | undefined,
    icon       :: binary() | undefined,
    created_at :: integer()
}).

-export_type([folder_initiated_v1/0]).
-opaque folder_initiated_v1() :: #folder_initiated_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> folder_initiated_v1().
event_type() -> folder_initiated_v1.

new(#{folder_id := FolderId, name := Name} = Params) ->
    #folder_initiated_v1{
        folder_id  = FolderId,
        name       = Name,
        parent_id  = maps:get(parent_id, Params, undefined),
        icon       = maps:get(icon, Params, undefined),
        created_at = erlang:system_time(millisecond)
    }.

-spec to_map(folder_initiated_v1()) -> map().
to_map(#folder_initiated_v1{} = E) ->
    Base = #{
        event_type => <<"folder_initiated_v1">>,
        folder_id  => E#folder_initiated_v1.folder_id,
        name       => E#folder_initiated_v1.name,
        created_at => E#folder_initiated_v1.created_at
    },
    maybe_put(icon, E#folder_initiated_v1.icon,
    maybe_put(parent_id, E#folder_initiated_v1.parent_id, Base)).

-spec from_map(map()) -> {ok, folder_initiated_v1()} | {error, term()}.
from_map(Map) ->
    FolderId = get_value(folder_id, Map),
    Name     = get_value(name, Map),
    case {FolderId, Name} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ ->
            {ok, #folder_initiated_v1{
                folder_id  = FolderId,
                name       = Name,
                parent_id  = get_value(parent_id, Map, undefined),
                icon       = get_value(icon, Map, undefined),
                created_at = get_value(created_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_folder_id(folder_initiated_v1()) -> binary().
get_folder_id(#folder_initiated_v1{folder_id = V}) -> V.

-spec get_name(folder_initiated_v1()) -> binary().
get_name(#folder_initiated_v1{name = V}) -> V.

-spec get_parent_id(folder_initiated_v1()) -> binary() | undefined.
get_parent_id(#folder_initiated_v1{parent_id = V}) -> V.

-spec get_icon(folder_initiated_v1()) -> binary() | undefined.
get_icon(#folder_initiated_v1{icon = V}) -> V.

-spec get_created_at(folder_initiated_v1()) -> integer().
get_created_at(#folder_initiated_v1{created_at = V}) -> V.

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
