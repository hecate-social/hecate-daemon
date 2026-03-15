%%% @doc launcher_reorganized_v1 event
%%% Emitted when the full launcher layout is reorganized.
-module(launcher_reorganized_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_groups/1, get_reorganized_at/1]).

-record(launcher_reorganized_v1, {
    groups         :: [map()],
    reorganized_at :: integer()
}).

-export_type([launcher_reorganized_v1/0]).
-opaque launcher_reorganized_v1() :: #launcher_reorganized_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> launcher_reorganized_v1().
event_type() -> launcher_reorganized_v1.

new(#{groups := Groups}) ->
    #launcher_reorganized_v1{
        groups         = Groups,
        reorganized_at = erlang:system_time(millisecond)
    }.

-spec to_map(launcher_reorganized_v1()) -> map().
to_map(#launcher_reorganized_v1{} = E) ->
    #{
        event_type     => <<"launcher_reorganized_v1">>,
        groups         => E#launcher_reorganized_v1.groups,
        reorganized_at => E#launcher_reorganized_v1.reorganized_at
    }.

-spec from_map(map()) -> {ok, launcher_reorganized_v1()} | {error, term()}.
from_map(Map) ->
    Groups = get_value(groups, Map),
    case Groups of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #launcher_reorganized_v1{
                groups         = Groups,
                reorganized_at = get_value(reorganized_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_groups(launcher_reorganized_v1()) -> [map()].
get_groups(#launcher_reorganized_v1{groups = V}) -> V.

-spec get_reorganized_at(launcher_reorganized_v1()) -> integer().
get_reorganized_at(#launcher_reorganized_v1{reorganized_at = V}) -> V.

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
