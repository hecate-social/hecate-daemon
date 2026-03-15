%%% @doc Launcher state module — implements evoq_state behaviour.
%%%
%%% Owns the launcher_state record, initial state creation, event folding,
%%% and serialization. Extracted from launcher_aggregate to separate
%%% state concerns from command validation.
%%% @end
-module(launcher_state).

-behaviour(evoq_state).

-include("launcher_status.hrl").
-include("launcher_state.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #launcher_state{}.
-export_type([state/0]).

%% --- evoq_state callbacks ---

-spec new(binary()) -> state().
new(_AggregateId) ->
    #launcher_state{status = 0, groups = []}.

-spec apply_event(state(), map()) -> state().

apply_event(S, #{event_type := <<"launcher_initialized_v1">>} = E)  -> apply_initialized(E, S);
apply_event(S, #{event_type := <<"entry_registered_v1">>} = E)      -> apply_registered(E, S);
apply_event(S, #{event_type := <<"entry_unregistered_v1">>} = E)    -> apply_unregistered(E, S);
apply_event(S, #{event_type := <<"launcher_reorganized_v1">>} = E)  -> apply_reorganized(E, S);
%% Unknown — ignore
apply_event(S, _E) -> S.

-spec to_map(state()) -> map().
to_map(#launcher_state{} = S) ->
    #{
        status => S#launcher_state.status,
        groups => S#launcher_state.groups
    }.

%% --- Apply helpers ---

apply_initialized(E, _State) ->
    Groups = get_value(groups, E, []),
    #launcher_state{
        status = ?LNCH_INITIALIZED,
        groups = normalize_groups(Groups)
    }.

apply_registered(E, #launcher_state{status = Status, groups = Groups}) ->
    EntryId = get_value(entry_id, E),
    GroupName = coalesce(get_value(group_name, E), <<"APPS">>),
    GroupIcon = get_value(group_icon, E),
    NewGroups = add_entry_to_group(EntryId, GroupName, GroupIcon, Groups),
    #launcher_state{
        status = evoq_bit_flags:set(Status, ?LNCH_CONFIGURED),
        groups = NewGroups
    }.

apply_unregistered(E, #launcher_state{status = Status, groups = Groups}) ->
    EntryId = get_value(entry_id, E),
    NewGroups = remove_entry_from_groups(EntryId, Groups),
    #launcher_state{
        status = evoq_bit_flags:set(Status, ?LNCH_CONFIGURED),
        groups = NewGroups
    }.

apply_reorganized(E, #launcher_state{status = Status}) ->
    Groups = get_value(groups, E, []),
    #launcher_state{
        status = evoq_bit_flags:set(Status, ?LNCH_CONFIGURED),
        groups = normalize_groups(Groups)
    }.

%% --- Group manipulation helpers ---

add_entry_to_group(EntryId, GroupName, GroupIcon, Groups) ->
    case find_group(GroupName, Groups) of
        {ok, Group} ->
            Apps = maps:get(apps, Group, maps:get(<<"apps">>, Group, [])),
            UpdatedGroup = Group#{apps => Apps ++ [EntryId]},
            replace_group(GroupName, UpdatedGroup, Groups);
        not_found ->
            DefaultIcon = <<"\xF0\x9F\x94\x8C">>,
            NewGroup = #{
                name => GroupName,
                icon => coalesce(GroupIcon, DefaultIcon),
                collapsed => false,
                apps => [EntryId]
            },
            Groups ++ [NewGroup]
    end.

remove_entry_from_groups(EntryId, Groups) ->
    lists:map(fun(Group) ->
        Apps = maps:get(apps, Group, maps:get(<<"apps">>, Group, [])),
        FilteredApps = lists:filter(fun(A) -> A =/= EntryId end, Apps),
        Group#{apps => FilteredApps}
    end, Groups).

find_group(GroupName, Groups) ->
    case lists:filter(fun(G) ->
        Name = maps:get(name, G, maps:get(<<"name">>, G, undefined)),
        Name =:= GroupName
    end, Groups) of
        [Group | _] -> {ok, Group};
        [] -> not_found
    end.

replace_group(GroupName, NewGroup, Groups) ->
    lists:map(fun(G) ->
        Name = maps:get(name, G, maps:get(<<"name">>, G, undefined)),
        case Name =:= GroupName of
            true -> NewGroup;
            false -> G
        end
    end, Groups).

normalize_groups(Groups) when is_list(Groups) ->
    lists:map(fun normalize_group/1, Groups);
normalize_groups(_) ->
    [].

normalize_group(G) when is_map(G) ->
    #{
        name => maps:get(name, G, maps:get(<<"name">>, G, <<>>)),
        icon => maps:get(icon, G, maps:get(<<"icon">>, G, <<>>)),
        collapsed => maps:get(collapsed, G, maps:get(<<"collapsed">>, G, false)),
        apps => maps:get(apps, G, maps:get(<<"apps">>, G, []))
    };
normalize_group(_) ->
    #{name => <<>>, icon => <<>>, collapsed => false, apps => []}.

%% --- Internal ---

get_value(Key, Map) ->
    get_value(Key, Map, undefined).

get_value(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, Default)
    end.

coalesce(undefined, Default) -> Default;
coalesce(null, Default) -> Default;
coalesce(<<"undefined">>, Default) -> Default;
coalesce(<<"null">>, Default) -> Default;
coalesce(<<>>, Default) -> Default;
coalesce(Value, _Default) -> Value.
