%%% @doc Launcher aggregate (singleton).
%%%
%%% Stream: launcher-launcher
%%% Store: launcher_store
%%%
%%% Lifecycle:
%%%   1. initialize_launcher (birth event - launcher_initialized_v1)
%%%   2. register_entry (add app to launcher)
%%%   3. unregister_entry (remove app from launcher)
%%%   4. reorganize_launcher (full layout update)
%%% @end
-module(launcher_aggregate).

-behaviour(evoq_aggregate).

-include("launcher_status.hrl").
-include("launcher_state.hrl").

-export([init/1, execute/2, apply/2]).
-export([initial_state/0, apply_event/2]).
-export([flag_map/0]).

-type state() :: #launcher_state{}.
-export_type([state/0]).

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?LNCH_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #launcher_state{status = 0, groups = []}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) - State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only initialize_launcher allowed
execute(#launcher_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"initialize_launcher">> -> execute_initialize(Payload);
        _ -> {error, launcher_not_initialized}
    end;

%% Initialized — route commands
execute(#launcher_state{status = S} = State, Payload) when S band ?LNCH_INITIALIZED =/= 0 ->
    case get_command_type(Payload) of
        <<"initialize_launcher">> -> {error, launcher_already_initialized};
        <<"register_entry">> -> execute_register_entry(Payload, State);
        <<"unregister_entry">> -> execute_unregister_entry(Payload, State);
        <<"reorganize_launcher">> -> execute_reorganize(Payload, State);
        _ -> {error, unknown_command}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_initialize(Payload) ->
    {ok, Cmd} = initialize_launcher_v1:from_map(Payload),
    convert_events(maybe_initialize_launcher:handle(Cmd), fun launcher_initialized_v1:to_map/1).

execute_register_entry(Payload, State) ->
    {ok, Cmd} = register_entry_v1:from_map(Payload),
    convert_events(maybe_register_entry:handle(Cmd, State), fun entry_registered_v1:to_map/1).

execute_unregister_entry(Payload, State) ->
    {ok, Cmd} = unregister_entry_v1:from_map(Payload),
    convert_events(maybe_unregister_entry:handle(Cmd, State), fun entry_unregistered_v1:to_map/1).

execute_reorganize(Payload, State) ->
    {ok, Cmd} = reorganize_launcher_v1:from_map(Payload),
    convert_events(maybe_reorganize_launcher:handle(Cmd, State), fun launcher_reorganized_v1:to_map/1).

%% --- Apply ---
%% NOTE: evoq calls apply(State, Event) - State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

-spec apply_event(map(), state()) -> state().

apply_event(#{<<"event_type">> := <<"launcher_initialized_v1">>} = E, S) -> apply_initialized(E, S);
apply_event(#{event_type := <<"launcher_initialized_v1">>} = E, S)      -> apply_initialized(E, S);
apply_event(#{<<"event_type">> := <<"entry_registered_v1">>} = E, S)    -> apply_registered(E, S);
apply_event(#{event_type := <<"entry_registered_v1">>} = E, S)          -> apply_registered(E, S);
apply_event(#{<<"event_type">> := <<"entry_unregistered_v1">>} = E, S)  -> apply_unregistered(E, S);
apply_event(#{event_type := <<"entry_unregistered_v1">>} = E, S)        -> apply_unregistered(E, S);
apply_event(#{<<"event_type">> := <<"launcher_reorganized_v1">>} = E, S) -> apply_reorganized(E, S);
apply_event(#{event_type := <<"launcher_reorganized_v1">>} = E, S)       -> apply_reorganized(E, S);
%% Unknown — ignore
apply_event(_E, S) -> S.

%% --- Apply helpers ---

apply_initialized(E, _State) ->
    Groups = get_value(groups, E, []),
    #launcher_state{
        status = ?LNCH_INITIALIZED,
        groups = normalize_groups(Groups)
    }.

apply_registered(E, #launcher_state{status = Status, groups = Groups}) ->
    EntryId = get_value(entry_id, E),
    GroupName = get_value(group_name, E),
    NewGroups = add_entry_to_group(EntryId, GroupName, Groups),
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

add_entry_to_group(EntryId, GroupName, Groups) ->
    case find_group(GroupName, Groups) of
        {ok, Group} ->
            Apps = maps:get(apps, Group, maps:get(<<"apps">>, Group, [])),
            UpdatedGroup = Group#{apps => Apps ++ [EntryId]},
            replace_group(GroupName, UpdatedGroup, Groups);
        not_found ->
            NewGroup = #{
                name => GroupName,
                icon => <<"\xF0\x9F\x94\x8C">>,
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

get_command_type(#{<<"command_type">> := T}) -> T;
get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

get_value(Key, Map) ->
    get_value(Key, Map, undefined).

get_value(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, Default)
    end.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
