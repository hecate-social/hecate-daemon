%%% @doc Merged projection: all launcher events -> launcher ETS read model.
%%%
%%% Handles launcher_initialized_v1, entry_registered_v1,
%%% entry_unregistered_v1, and launcher_reorganized_v1 in a single
%%% projection to eliminate race conditions between separate projections
%%% writing to the same ETS tables.
%%% @end
-module(launcher_lifecycle_to_launcher).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

interested_in() ->
    [<<"launcher_initialized_v1">>,
     <<"entry_registered_v1">>,
     <<"entry_unregistered_v1">>,
     <<"launcher_reorganized_v1">>].

init(_Config) ->
    {ok, EntryRM} = evoq_read_model:new(evoq_read_model_ets, #{name => launcher_entries}),
    {ok, GroupRM} = evoq_read_model:new(evoq_read_model_ets, #{name => launcher_groups}),
    {ok, #{group_rm => GroupRM}, EntryRM}.

%% -- launcher_initialized_v1: clear and rebuild from init payload --
project(#{event_type := <<"launcher_initialized_v1">>, data := Data},
        _Metadata, #{group_rm := GroupRM} = State, EntryRM) ->
    rebuild_from_groups(Data, State, GroupRM, EntryRM);

%% -- launcher_reorganized_v1: clear and rebuild from reorganize payload --
project(#{event_type := <<"launcher_reorganized_v1">>, data := Data},
        _Metadata, #{group_rm := GroupRM} = State, EntryRM) ->
    rebuild_from_groups(Data, State, GroupRM, EntryRM);

%% -- entry_registered_v1: insert entry and ensure group exists --
project(#{event_type := <<"entry_registered_v1">>, data := Data},
        _Metadata, #{group_rm := GroupRM} = State, EntryRM) ->
    EntryId = gf(entry_id, Data),
    DisplayName = gf(display_name, Data),
    Icon = gf(icon, Data),
    GroupName = coalesce(gf(group_name, Data), <<"APPS">>),
    GroupIcon = gf(group_icon, Data),
    RegisteredAt = gf(registered_at, Data),
    %% Ensure group exists
    GroupRM2 = case evoq_read_model:get(GroupName, GroupRM) of
        {ok, _} -> GroupRM;
        {error, not_found} ->
            NextPos = ets:info(launcher_groups, size),
            Group = #{
                name      => GroupName,
                icon      => coalesce(GroupIcon, <<"\xF0\x9F\x93\x81">>),
                collapsed => false,
                position  => NextPos
            },
            {ok, GRM} = evoq_read_model:put(GroupName, Group, GroupRM),
            GRM
    end,
    %% Count existing entries in group for position
    All = ets:tab2list(launcher_entries),
    Pos = length([E || {_K, #{group_name := GN} = E} <- All, GN =:= GroupName, _ = E]),
    Entry = #{
        entry_id      => EntryId,
        display_name  => DisplayName,
        icon          => Icon,
        group_name    => GroupName,
        group_icon    => GroupIcon,
        position      => Pos,
        registered_at     => RegisteredAt,
        status            => 1,
        status_label      => <<"Active">>,
        available_actions => []
    },
    {ok, EntryRM2} = evoq_read_model:put(EntryId, Entry, EntryRM),
    {ok, State#{group_rm => GroupRM2}, EntryRM2};

%% -- entry_unregistered_v1: remove entry --
project(#{event_type := <<"entry_unregistered_v1">>, data := Data},
        _Metadata, State, EntryRM) ->
    EntryId = gf(entry_id, Data),
    {ok, EntryRM2} = evoq_read_model:delete(EntryId, EntryRM),
    {ok, State, EntryRM2}.

%% -- Internal --

rebuild_from_groups(Data, State, GroupRM, EntryRM) ->
    Groups = gf(groups, Data),
    evoq_read_model:clear(EntryRM),
    evoq_read_model:clear(GroupRM),
    {EntryRM2, GroupRM2, _} = lists:foldl(fun(Group, {ERM, GRM, GPos}) ->
        Name = gv(name, Group),
        Icon = gv(icon, Group, <<"\xF0\x9F\x93\x81">>),
        Collapsed = gv(collapsed, Group, false),
        Apps = gv(apps, Group, []),
        GroupEntry = #{
            name      => Name,
            icon      => Icon,
            collapsed => Collapsed,
            position  => GPos
        },
        {ok, GRM2} = evoq_read_model:put(Name, GroupEntry, GRM),
        ERM2 = lists:foldl(fun(AppId, {ERMA, EPos}) ->
            Entry = #{
                entry_id      => AppId,
                display_name  => AppId,
                icon          => <<"\xF0\x9F\x94\x8C">>,
                group_name    => Name,
                position      => EPos,
                registered_at     => undefined,
                status            => 1,
                status_label      => <<"Active">>,
                available_actions => []
            },
            {ok, ERMA2} = evoq_read_model:put(AppId, Entry, ERMA),
            {ERMA2, EPos + 1}
        end, {ERM, 0}, Apps),
        {element(1, ERM2), GRM2, GPos + 1}
    end, {EntryRM, GroupRM, 0}, Groups),
    {ok, State#{group_rm => GroupRM2}, EntryRM2}.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).

coalesce(undefined, Default) -> Default;
coalesce(null, Default) -> Default;
coalesce(<<"undefined">>, Default) -> Default;
coalesce(<<"null">>, Default) -> Default;
coalesce(<<>>, Default) -> Default;
coalesce(Value, _Default) -> Value.

gv(Key, Map) when is_map(Map) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(BinKey, Map)
    end.

gv(Key, Map, Default) when is_map(Map) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(BinKey, Map, Default)
    end.
