%%% @doc Projection: entry_registered_v1 -> launcher ETS read model.
%%% Inserts a launcher entry and ensures its group exists.
-module(entry_registered_v1_to_launcher).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

interested_in() -> [<<"entry_registered_v1">>].

init(_Config) ->
    {ok, EntryRM} = evoq_read_model:new(evoq_read_model_ets, #{name => launcher_entries}),
    {ok, GroupRM} = evoq_read_model:new(evoq_read_model_ets, #{name => launcher_groups}),
    {ok, #{group_rm => GroupRM}, EntryRM}.

project(#{data := Data}, _Metadata, #{group_rm := GroupRM} = State, EntryRM) ->
    EntryId = gf(entry_id, Data),
    DisplayName = gf(display_name, Data),
    Icon = gf(icon, Data),
    GroupName = gf(group_name, Data),
    RegisteredAt = gf(registered_at, Data),
    %% Ensure group exists
    GroupRM2 = case evoq_read_model:get(GroupName, GroupRM) of
        {ok, _} -> GroupRM;
        {error, not_found} ->
            NextPos = ets:info(launcher_groups, size),
            Group = #{
                name      => GroupName,
                icon      => <<"\xF0\x9F\x93\x81">>,
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
        position      => Pos,
        registered_at => RegisteredAt,
        status        => 1,
        status_label  => <<"Active">>
    },
    {ok, EntryRM2} = evoq_read_model:put(EntryId, Entry, EntryRM),
    {ok, State#{group_rm => GroupRM2}, EntryRM2}.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
