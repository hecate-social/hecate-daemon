%%% @doc Plugin aggregate (node context).
%%%
%%% Stream: plugin-{plugin_id}
%%% Store: plugins_store
%%%
%%% Lifecycle:
%%%   1. install_plugin (birth event - plugin_installed_v1)
%%%   2. upgrade_plugin
%%%   3. remove_plugin
%%% @end
-module(plugin_aggregate).

-behaviour(evoq_aggregate).

-include("plugin_status.hrl").
-include("plugin_state.hrl").

-export([init/1, execute/2, apply/2]).
-export([initial_state/0, apply_event/2]).
-export([flag_map/0]).

-type state() :: #plugin_state{}.
-export_type([state/0]).

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?PLG_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #plugin_state{status = 0}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) - State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only install_plugin allowed
execute(#plugin_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"install_plugin">> -> execute_install_plugin(Payload);
        _ -> {error, plugin_not_installed}
    end;

%% Removed — allow re-install
execute(#plugin_state{status = S}, Payload) when S band ?PLG_REMOVED =/= 0 ->
    case get_command_type(Payload) of
        <<"install_plugin">> -> execute_install_plugin(Payload);
        _ -> {error, plugin_removed}
    end;

%% Installed — route by command type
execute(#plugin_state{status = S} = State, Payload) when S band ?PLG_INSTALLED =/= 0 ->
    case get_command_type(Payload) of
        <<"install_plugin">>  -> {error, plugin_already_installed};
        <<"upgrade_plugin">>  -> execute_upgrade_plugin(Payload, State);
        <<"remove_plugin">>   -> execute_remove_plugin(Payload, State);
        _ -> {error, unknown_command}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_install_plugin(Payload) ->
    {ok, Cmd} = install_plugin_v1:from_map(Payload),
    convert_events(maybe_install_plugin:handle(Cmd), fun plugin_installed_v1:to_map/1).

execute_upgrade_plugin(Payload, _State) ->
    {ok, Cmd} = upgrade_plugin_v1:from_map(Payload),
    convert_events(maybe_upgrade_plugin:handle(Cmd), fun plugin_upgraded_v1:to_map/1).

execute_remove_plugin(Payload, _State) ->
    {ok, Cmd} = remove_plugin_v1:from_map(Payload),
    convert_events(maybe_remove_plugin:handle(Cmd), fun plugin_removed_v1:to_map/1).

%% --- Apply ---
%% NOTE: evoq calls apply(State, Event) - State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

-spec apply_event(map(), state()) -> state().

apply_event(#{<<"event_type">> := <<"plugin_installed_v1">>} = E, S) -> apply_installed(E, S);
apply_event(#{event_type := <<"plugin_installed_v1">>} = E, S)      -> apply_installed(E, S);
apply_event(#{<<"event_type">> := <<"plugin_upgraded_v1">>} = E, S)  -> apply_upgraded(E, S);
apply_event(#{event_type := <<"plugin_upgraded_v1">>} = E, S)       -> apply_upgraded(E, S);
apply_event(#{<<"event_type">> := <<"plugin_removed_v1">>} = E, S)  -> apply_removed(E, S);
apply_event(#{event_type := <<"plugin_removed_v1">>} = E, S)        -> apply_removed(E, S);
%% Unknown — ignore
apply_event(_E, S) -> S.

%% --- Apply helpers ---

apply_installed(E, _State) ->
    #plugin_state{
        plugin_id = get_value(plugin_id, E),
        name = get_value(name, E),
        oci_image = get_value(oci_image, E),
        installed_version = get_value(installed_version, E),
        license_id = get_value(license_id, E),
        installed_at = get_value(installed_at, E),
        upgraded_at = undefined,
        removed_at = undefined,
        status = ?PLG_INSTALLED
    }.

apply_upgraded(E, #plugin_state{} = State) ->
    State#plugin_state{
        oci_image = get_value(oci_image, E),
        installed_version = get_value(installed_version, E),
        upgraded_at = get_value(upgraded_at, E)
    }.

apply_removed(E, #plugin_state{status = Status} = State) ->
    State#plugin_state{
        status = evoq_bit_flags:set(Status, ?PLG_REMOVED),
        removed_at = get_value(removed_at, E)
    }.

%% --- Internal ---

get_command_type(#{<<"command_type">> := T}) -> T;
get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
