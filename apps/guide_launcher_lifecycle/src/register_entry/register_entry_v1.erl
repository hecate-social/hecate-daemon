%%% @doc register_entry_v1 command
%%% Adds an app entry to the launcher sidebar.
-module(register_entry_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_entry_id/1, get_display_name/1, get_icon/1, get_group_name/1]).

-record(register_entry_v1, {
    entry_id     :: binary(),
    display_name :: binary(),
    icon         :: binary(),
    group_name   :: binary()
}).

-export_type([register_entry_v1/0]).
-opaque register_entry_v1() :: #register_entry_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, register_entry_v1()} | {error, term()}.
new(#{entry_id := EntryId, display_name := DisplayName,
      icon := Icon, group_name := GroupName}) ->
    {ok, #register_entry_v1{
        entry_id     = EntryId,
        display_name = DisplayName,
        icon         = Icon,
        group_name   = GroupName
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(register_entry_v1()) -> {ok, register_entry_v1()} | {error, term()}.
validate(#register_entry_v1{entry_id = EntryId}) when
    not is_binary(EntryId); byte_size(EntryId) =:= 0 ->
    {error, invalid_entry_id};
validate(#register_entry_v1{display_name = Name}) when
    not is_binary(Name); byte_size(Name) =:= 0 ->
    {error, invalid_display_name};
validate(#register_entry_v1{group_name = Group}) when
    not is_binary(Group); byte_size(Group) =:= 0 ->
    {error, invalid_group_name};
validate(#register_entry_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(register_entry_v1()) -> map().
to_map(#register_entry_v1{} = Cmd) ->
    #{
        <<"command_type">>  => <<"register_entry">>,
        <<"entry_id">>      => Cmd#register_entry_v1.entry_id,
        <<"display_name">>  => Cmd#register_entry_v1.display_name,
        <<"icon">>          => Cmd#register_entry_v1.icon,
        <<"group_name">>    => Cmd#register_entry_v1.group_name
    }.

-spec from_map(map()) -> {ok, register_entry_v1()} | {error, term()}.
from_map(Map) ->
    EntryId     = get_value(entry_id, Map),
    DisplayName = get_value(display_name, Map),
    Icon        = get_value(icon, Map),
    GroupName   = get_value(group_name, Map),
    case {EntryId, DisplayName, GroupName} of
        {undefined, _, _} -> {error, missing_required_fields};
        {_, undefined, _} -> {error, missing_required_fields};
        {_, _, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #register_entry_v1{
                entry_id     = EntryId,
                display_name = DisplayName,
                icon         = case Icon of undefined -> <<>>; _ -> Icon end,
                group_name   = GroupName
            }}
    end.

%% Accessors
-spec get_entry_id(register_entry_v1()) -> binary().
get_entry_id(#register_entry_v1{entry_id = V}) -> V.

-spec get_display_name(register_entry_v1()) -> binary().
get_display_name(#register_entry_v1{display_name = V}) -> V.

-spec get_icon(register_entry_v1()) -> binary().
get_icon(#register_entry_v1{icon = V}) -> V.

-spec get_group_name(register_entry_v1()) -> binary().
get_group_name(#register_entry_v1{group_name = V}) -> V.

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
