%%% @doc entry_unregistered_v1 event
%%% Emitted when an app entry is removed from the launcher.
-module(entry_unregistered_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_entry_id/1, get_unregistered_at/1]).

-record(entry_unregistered_v1, {
    entry_id        :: binary(),
    unregistered_at :: integer()
}).

-export_type([entry_unregistered_v1/0]).
-opaque entry_unregistered_v1() :: #entry_unregistered_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> entry_unregistered_v1().
new(#{entry_id := EntryId}) ->
    #entry_unregistered_v1{
        entry_id        = EntryId,
        unregistered_at = erlang:system_time(millisecond)
    }.

-spec to_map(entry_unregistered_v1()) -> map().
to_map(#entry_unregistered_v1{} = E) ->
    #{
        event_type      => <<"entry_unregistered_v1">>,
        entry_id        => E#entry_unregistered_v1.entry_id,
        unregistered_at => E#entry_unregistered_v1.unregistered_at
    }.

-spec from_map(map()) -> {ok, entry_unregistered_v1()} | {error, term()}.
from_map(Map) ->
    EntryId = get_value(entry_id, Map),
    case EntryId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #entry_unregistered_v1{
                entry_id        = EntryId,
                unregistered_at = get_value(unregistered_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_entry_id(entry_unregistered_v1()) -> binary().
get_entry_id(#entry_unregistered_v1{entry_id = V}) -> V.

-spec get_unregistered_at(entry_unregistered_v1()) -> integer().
get_unregistered_at(#entry_unregistered_v1{unregistered_at = V}) -> V.

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
