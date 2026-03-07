%%% @doc Projection: launcher_reorganized_v1 -> launcher ETS read model.
%%% Clears and rebuilds both entries and groups from the reorganize payload.
-module(launcher_reorganized_v1_to_launcher).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

interested_in() -> [<<"launcher_reorganized_v1">>].

init(_Config) ->
    {ok, EntryRM} = evoq_read_model:new(evoq_read_model_ets, #{name => launcher_entries}),
    {ok, GroupRM} = evoq_read_model:new(evoq_read_model_ets, #{name => launcher_groups}),
    {ok, #{group_rm => GroupRM}, EntryRM}.

project(#{data := Data}, _Metadata, #{group_rm := GroupRM} = State, EntryRM) ->
    Groups = gf(groups, Data),
    %% Clear both tables
    evoq_read_model:clear(EntryRM),
    evoq_read_model:clear(GroupRM),
    %% Rebuild
    {EntryRM2, GroupRM2} = lists:foldl(fun(Group, {ERM, GRM, GPos}) ->
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
                registered_at => undefined,
                status        => 1,
                status_label  => <<"Active">>
            },
            {ok, ERMA2} = evoq_read_model:put(AppId, Entry, ERMA),
            {ERMA2, EPos + 1}
        end, {ERM, 0}, Apps),
        {element(1, ERM2), GRM2, GPos + 1}
    end, {EntryRM, GroupRM, 0}, Groups),
    {ok, State#{group_rm => GroupRM2}, EntryRM2}.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).

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
