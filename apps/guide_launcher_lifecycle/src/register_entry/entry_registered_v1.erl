%%% @doc entry_registered_v1 event
%%% Emitted when an app entry is added to the launcher.
-module(entry_registered_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_entry_id/1, get_display_name/1, get_icon/1,
         get_group_name/1, get_registered_at/1]).

-record(entry_registered_v1, {
    entry_id      :: binary(),
    display_name  :: binary(),
    icon          :: binary(),
    group_name    :: binary(),
    registered_at :: integer()
}).

-export_type([entry_registered_v1/0]).
-opaque entry_registered_v1() :: #entry_registered_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> entry_registered_v1().
new(#{entry_id := EntryId, display_name := DisplayName,
      icon := Icon, group_name := GroupName}) ->
    #entry_registered_v1{
        entry_id      = EntryId,
        display_name  = DisplayName,
        icon          = Icon,
        group_name    = GroupName,
        registered_at = erlang:system_time(millisecond)
    }.

-spec to_map(entry_registered_v1()) -> map().
to_map(#entry_registered_v1{} = E) ->
    #{
        event_type    => <<"entry_registered_v1">>,
        entry_id      => E#entry_registered_v1.entry_id,
        display_name  => E#entry_registered_v1.display_name,
        icon          => E#entry_registered_v1.icon,
        group_name    => E#entry_registered_v1.group_name,
        registered_at => E#entry_registered_v1.registered_at
    }.

-spec from_map(map()) -> {ok, entry_registered_v1()} | {error, term()}.
from_map(Map) ->
    EntryId     = get_value(entry_id, Map),
    DisplayName = get_value(display_name, Map),
    Icon        = get_value(icon, Map),
    GroupName   = get_value(group_name, Map),
    case {EntryId, DisplayName, GroupName} of
        {undefined, _, _} -> {error, invalid_event};
        {_, undefined, _} -> {error, invalid_event};
        {_, _, undefined} -> {error, invalid_event};
        _ ->
            {ok, #entry_registered_v1{
                entry_id      = EntryId,
                display_name  = DisplayName,
                icon          = case Icon of undefined -> <<>>; _ -> Icon end,
                group_name    = GroupName,
                registered_at = get_value(registered_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_entry_id(entry_registered_v1()) -> binary().
get_entry_id(#entry_registered_v1{entry_id = V}) -> V.

-spec get_display_name(entry_registered_v1()) -> binary().
get_display_name(#entry_registered_v1{display_name = V}) -> V.

-spec get_icon(entry_registered_v1()) -> binary().
get_icon(#entry_registered_v1{icon = V}) -> V.

-spec get_group_name(entry_registered_v1()) -> binary().
get_group_name(#entry_registered_v1{group_name = V}) -> V.

-spec get_registered_at(entry_registered_v1()) -> integer().
get_registered_at(#entry_registered_v1{registered_at = V}) -> V.

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
