%%% @doc launcher_initialized_v1 event
%%% Emitted when the launcher singleton is first initialized with default groups.
-module(launcher_initialized_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_groups/1, get_initialized_at/1]).

-record(launcher_initialized_v1, {
    groups         :: [map()],
    initialized_at :: integer()
}).

-export_type([launcher_initialized_v1/0]).
-opaque launcher_initialized_v1() :: #launcher_initialized_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> launcher_initialized_v1().
new(#{groups := Groups}) ->
    #launcher_initialized_v1{
        groups         = Groups,
        initialized_at = erlang:system_time(millisecond)
    }.

-spec to_map(launcher_initialized_v1()) -> map().
to_map(#launcher_initialized_v1{} = E) ->
    #{
        event_type     => <<"launcher_initialized_v1">>,
        groups         => E#launcher_initialized_v1.groups,
        initialized_at => E#launcher_initialized_v1.initialized_at
    }.

-spec from_map(map()) -> {ok, launcher_initialized_v1()} | {error, term()}.
from_map(Map) ->
    Groups = get_value(groups, Map),
    case Groups of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #launcher_initialized_v1{
                groups         = Groups,
                initialized_at = get_value(initialized_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_groups(launcher_initialized_v1()) -> [map()].
get_groups(#launcher_initialized_v1{groups = V}) -> V.

-spec get_initialized_at(launcher_initialized_v1()) -> integer().
get_initialized_at(#launcher_initialized_v1{initialized_at = V}) -> V.

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
