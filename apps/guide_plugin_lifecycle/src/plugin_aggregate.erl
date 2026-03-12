%%% @doc Plugin aggregate (node context).
%%%
%%% Stream: plugin-{plugin_id}
%%% Store: plugins_store
%%%
%%% Supports two plugin models via plugin_type field:
%%%   container: OCI/Podman lifecycle (pull, start, stop, confirm up/down)
%%%   in_vm:     In-VM OTP application lifecycle (extract, activate, deactivate, confirm load/unload)
%%%
%%% Common lifecycle:
%%%   1. install_plugin (birth event)
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
execute(#plugin_state{status = S} = State, Payload)
  when S band ?PLG_INSTALLED =/= 0 ->
    case get_command_type(Payload) of
        <<"install_plugin">>            -> {error, plugin_already_installed};
        <<"upgrade_plugin">>            -> execute_upgrade_plugin(Payload, State);
        <<"remove_plugin">>             -> execute_remove_plugin(Payload, State);
        %% Container-model commands
        <<"start_plugin_execution">>    -> execute_start_execution(Payload, State);
        <<"stop_plugin_execution">>     -> execute_stop_execution(Payload, State);
        <<"confirm_container_up">>      -> execute_confirm_up(Payload);
        <<"confirm_container_down">>    -> execute_confirm_down(Payload);
        <<"start_oci_pull">>            -> execute_start_pull(Payload, S, State);
        <<"cancel_oci_pull">>           -> execute_cancel_pull(Payload, S);
        <<"complete_oci_pull">>         -> execute_complete_pull(Payload, S);
        %% In-VM model commands
        <<"extract_plugin_package">>    -> execute_extract_package(Payload, State);
        <<"activate_plugin">>           -> execute_activate_plugin(Payload, S);
        <<"deactivate_plugin">>         -> execute_deactivate_plugin(Payload, S);
        <<"confirm_plugin_loaded">>     -> execute_confirm_loaded(Payload);
        <<"confirm_plugin_unloaded">>   -> execute_confirm_unloaded(Payload);
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

execute_remove_plugin(Payload, State) ->
    {ok, Cmd} = remove_plugin_v1:from_map(Payload),
    convert_events(maybe_remove_plugin:handle(Cmd, State), fun plugin_removed_v1:to_map/1).

execute_start_execution(_Payload, #plugin_state{status = S}) when S band ?PLG_ACTIVATED =/= 0 ->
    {error, plugin_already_running};
execute_start_execution(_Payload, #plugin_state{status = S}) when S band ?PLG_RUNNING =/= 0 ->
    {error, plugin_already_running};
execute_start_execution(Payload, State) ->
    {ok, Cmd} = start_plugin_execution_v1:from_map(Payload),
    convert_events(maybe_start_plugin_execution:handle(Cmd, State), fun plugin_execution_started_v1:to_map/1).

execute_stop_execution(Payload, State) ->
    {ok, Cmd} = stop_plugin_execution_v1:from_map(Payload),
    convert_events(maybe_stop_plugin_execution:handle(Cmd, State), fun plugin_execution_stopped_v1:to_map/1).

execute_confirm_up(Payload) ->
    {ok, Cmd} = confirm_container_up_v1:from_map(Payload),
    convert_events(maybe_confirm_container_up:handle(Cmd), fun container_confirmed_up_v1:to_map/1).

execute_confirm_down(Payload) ->
    {ok, Cmd} = confirm_container_down_v1:from_map(Payload),
    convert_events(maybe_confirm_container_down:handle(Cmd), fun container_confirmed_down_v1:to_map/1).

execute_start_pull(Payload, Status, State) ->
    case Status band ?PLG_PULLING of
        0 ->
            {ok, Cmd} = start_oci_pull_v1:from_map(Payload),
            convert_events(maybe_start_oci_pull:handle(Cmd, State), fun oci_pull_started_v1:to_map/1);
        _ ->
            {error, already_pulling}
    end.

execute_cancel_pull(Payload, Status) ->
    case Status band ?PLG_PULLING of
        0 -> {error, not_pulling};
        _ ->
            {ok, Cmd} = cancel_oci_pull_v1:from_map(Payload),
            convert_events(maybe_cancel_oci_pull:handle(Cmd), fun oci_pull_cancelled_v1:to_map/1)
    end.

execute_complete_pull(Payload, Status) ->
    case Status band ?PLG_PULLING of
        0 -> {error, not_pulling};
        _ ->
            {ok, Cmd} = complete_oci_pull_v1:from_map(Payload),
            convert_events(maybe_complete_oci_pull:handle(Cmd), fun oci_pull_completed_v1:to_map/1)
    end.

%% In-VM command handlers

execute_extract_package(Payload, State) ->
    {ok, Cmd} = extract_plugin_package_v1:from_map(Payload),
    convert_events(maybe_extract_plugin_package:handle(Cmd, State), fun plugin_package_extracted_v1:to_map/1).

execute_activate_plugin(Payload, Status) ->
    case Status band ?PLG_ACTIVATED of
        0 ->
            {ok, Cmd} = activate_plugin_v1:from_map(Payload),
            convert_events(maybe_activate_plugin:handle(Cmd), fun plugin_activated_v1:to_map/1);
        _ ->
            {error, plugin_already_activated}
    end.

execute_deactivate_plugin(Payload, Status) ->
    case Status band ?PLG_ACTIVATED of
        0 -> {error, plugin_not_activated};
        _ ->
            {ok, Cmd} = deactivate_plugin_v1:from_map(Payload),
            convert_events(maybe_deactivate_plugin:handle(Cmd), fun plugin_deactivated_v1:to_map/1)
    end.

execute_confirm_loaded(Payload) ->
    {ok, Cmd} = confirm_plugin_loaded_v1:from_map(Payload),
    convert_events(maybe_confirm_plugin_loaded:handle(Cmd), fun plugin_load_confirmed_v1:to_map/1).

execute_confirm_unloaded(Payload) ->
    {ok, Cmd} = confirm_plugin_unloaded_v1:from_map(Payload),
    convert_events(maybe_confirm_plugin_unloaded:handle(Cmd), fun plugin_unload_confirmed_v1:to_map/1).

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
apply_event(#{<<"event_type">> := <<"plugin_execution_started_v1">>} = E, S) -> apply_started(E, S);
apply_event(#{event_type := <<"plugin_execution_started_v1">>} = E, S)       -> apply_started(E, S);
apply_event(#{<<"event_type">> := <<"plugin_execution_stopped_v1">>} = E, S) -> apply_stopped(E, S);
apply_event(#{event_type := <<"plugin_execution_stopped_v1">>} = E, S)       -> apply_stopped(E, S);
apply_event(#{<<"event_type">> := <<"container_confirmed_up_v1">>} = _E, S)  -> apply_confirmed_up(S);
apply_event(#{event_type := <<"container_confirmed_up_v1">>} = _E, S)        -> apply_confirmed_up(S);
apply_event(#{<<"event_type">> := <<"container_confirmed_down_v1">>} = _E, S) -> apply_confirmed_down(S);
apply_event(#{event_type := <<"container_confirmed_down_v1">>} = _E, S)       -> apply_confirmed_down(S);
apply_event(#{<<"event_type">> := <<"oci_pull_started_v1">>} = _E, S)   -> apply_pull_started(S);
apply_event(#{event_type := <<"oci_pull_started_v1">>} = _E, S)         -> apply_pull_started(S);
apply_event(#{<<"event_type">> := <<"oci_pull_cancelled_v1">>} = _E, S) -> apply_pull_cancelled(S);
apply_event(#{event_type := <<"oci_pull_cancelled_v1">>} = _E, S)       -> apply_pull_cancelled(S);
apply_event(#{<<"event_type">> := <<"oci_pull_completed_v1">>} = _E, S) -> apply_pull_completed(S);
apply_event(#{event_type := <<"oci_pull_completed_v1">>} = _E, S)       -> apply_pull_completed(S);
%% In-VM events
apply_event(#{<<"event_type">> := <<"plugin_package_extracted_v1">>} = E, S) -> apply_package_extracted(E, S);
apply_event(#{event_type := <<"plugin_package_extracted_v1">>} = E, S)      -> apply_package_extracted(E, S);
apply_event(#{<<"event_type">> := <<"plugin_activated_v1">>} = E, S)        -> apply_activated(E, S);
apply_event(#{event_type := <<"plugin_activated_v1">>} = E, S)              -> apply_activated(E, S);
apply_event(#{<<"event_type">> := <<"plugin_deactivated_v1">>} = E, S)      -> apply_deactivated(E, S);
apply_event(#{event_type := <<"plugin_deactivated_v1">>} = E, S)            -> apply_deactivated(E, S);
apply_event(#{<<"event_type">> := <<"plugin_load_confirmed_v1">>} = _E, S)  -> apply_load_confirmed(S);
apply_event(#{event_type := <<"plugin_load_confirmed_v1">>} = _E, S)        -> apply_load_confirmed(S);
apply_event(#{<<"event_type">> := <<"plugin_unload_confirmed_v1">>} = _E, S) -> apply_unload_confirmed(S);
apply_event(#{event_type := <<"plugin_unload_confirmed_v1">>} = _E, S)       -> apply_unload_confirmed(S);
%% Unknown — ignore
apply_event(_E, S) -> S.

%% --- Apply helpers ---

apply_installed(E, _State) ->
    #plugin_state{
        plugin_id = get_value(plugin_id, E),
        name = get_value(name, E),
        plugin_type = get_value(plugin_type, E),
        callback_module = get_value(callback_module, E),
        oci_image = get_value(oci_image, E),
        package_url = get_value(package_url, E),
        installed_version = get_value(installed_version, E),
        license_id = get_value(license_id, E),
        icon = get_value(icon, E),
        group_name = get_value(group_name, E),
        group_icon = get_value(group_icon, E),
        installed_at = get_value(installed_at, E),
        upgraded_at = undefined,
        removed_at = undefined,
        status = ?PLG_INSTALLED
    }.

apply_upgraded(E, #plugin_state{} = State) ->
    State#plugin_state{
        oci_image = coalesce(get_value(oci_image, E), State#plugin_state.oci_image),
        package_url = coalesce(get_value(package_url, E), State#plugin_state.package_url),
        plugin_type = coalesce(get_value(plugin_type, E), State#plugin_state.plugin_type),
        installed_version = get_value(installed_version, E),
        upgraded_at = get_value(upgraded_at, E),
        icon = coalesce(get_value(icon, E), State#plugin_state.icon),
        group_name = coalesce(get_value(group_name, E), State#plugin_state.group_name),
        group_icon = coalesce(get_value(group_icon, E), State#plugin_state.group_icon)
    }.

apply_removed(E, #plugin_state{status = Status} = State) ->
    State#plugin_state{
        status = evoq_bit_flags:set(Status, ?PLG_REMOVED),
        removed_at = get_value(removed_at, E)
    }.

apply_started(E, #plugin_state{status = Status} = State) ->
    NewStatus = evoq_bit_flags:unset(evoq_bit_flags:set(evoq_bit_flags:set(Status, ?PLG_RUNNING), ?PLG_PULLING), ?PLG_STOPPED),
    State#plugin_state{
        status = NewStatus,
        started_at = get_value(started_at, E),
        stopped_at = undefined
    }.

apply_stopped(E, #plugin_state{status = Status} = State) ->
    NewStatus = evoq_bit_flags:unset(evoq_bit_flags:set(Status, ?PLG_STOPPED), ?PLG_RUNNING),
    State#plugin_state{
        status = NewStatus,
        stopped_at = get_value(stopped_at, E)
    }.

apply_confirmed_up(#plugin_state{status = Status} = State) ->
    NewStatus = evoq_bit_flags:unset(evoq_bit_flags:unset(evoq_bit_flags:set(Status, ?PLG_CONFIRMED_UP), ?PLG_CONFIRMED_DOWN), ?PLG_PULLING),
    State#plugin_state{status = NewStatus}.

apply_confirmed_down(#plugin_state{status = Status} = State) ->
    NewStatus = evoq_bit_flags:unset(evoq_bit_flags:set(Status, ?PLG_CONFIRMED_DOWN), ?PLG_CONFIRMED_UP),
    State#plugin_state{status = NewStatus}.

apply_pull_started(#plugin_state{status = Status} = State) ->
    State#plugin_state{status = evoq_bit_flags:set(Status, ?PLG_PULLING)}.

apply_pull_cancelled(#plugin_state{status = Status} = State) ->
    State#plugin_state{status = evoq_bit_flags:unset(Status, ?PLG_PULLING)}.

apply_pull_completed(#plugin_state{status = Status} = State) ->
    State#plugin_state{status = evoq_bit_flags:unset(Status, ?PLG_PULLING)}.

%% In-VM apply helpers

apply_package_extracted(E, #plugin_state{} = State) ->
    CB = get_value(callback_module, E),
    State#plugin_state{
        status = evoq_bit_flags:unset(evoq_bit_flags:set(State#plugin_state.status, ?PLG_EXTRACTING), ?PLG_EXTRACTING),
        callback_module = case CB of undefined -> State#plugin_state.callback_module; _ -> CB end,
        extracted_at = get_value(extracted_at, E)
    }.

apply_activated(E, #plugin_state{status = Status} = State) ->
    NewStatus = evoq_bit_flags:unset(evoq_bit_flags:set(Status, ?PLG_ACTIVATED), ?PLG_DEACTIVATED),
    State#plugin_state{
        status = NewStatus,
        callback_module = get_value(callback_module, E),
        activated_at = get_value(activated_at, E),
        deactivated_at = undefined
    }.

apply_deactivated(E, #plugin_state{status = Status} = State) ->
    NewStatus = evoq_bit_flags:unset(evoq_bit_flags:set(Status, ?PLG_DEACTIVATED), ?PLG_ACTIVATED),
    State#plugin_state{
        status = NewStatus,
        deactivated_at = get_value(deactivated_at, E)
    }.

apply_load_confirmed(#plugin_state{} = State) ->
    %% Load confirmed is informational — ACTIVATED flag is already set
    State.

apply_unload_confirmed(#plugin_state{} = State) ->
    %% Unload confirmed is informational — DEACTIVATED flag is already set
    State.

%% --- Internal ---

get_command_type(#{<<"command_type">> := T}) -> T;
get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, null} -> undefined;
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.

%% @private Use new value if defined, otherwise keep existing.
coalesce(undefined, Existing) -> Existing;
coalesce(New, _Existing) -> New.
