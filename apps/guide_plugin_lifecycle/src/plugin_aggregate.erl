%%% @doc Plugin aggregate (node context).
%%%
%%% Stream: plugin-{plugin_id}
%%% Store: plugins_store
%%%
%%% Supports two plugin models via plugin_type field:
%%%   container: OCI/Podman lifecycle (pull, start, stop, confirm up/down)
%%%   in_vm:     In-VM OTP application lifecycle (extract, start, stop, confirm load/unload)
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
-export([state_module/0]).
-export([flag_map/0]).

-type state() :: #plugin_state{}.
-export_type([state/0]).

-spec state_module() -> module().
state_module() -> plugin_state.

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?PLG_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(AggregateId) ->
    {ok, plugin_state:new(AggregateId)}.

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
        %% Execution lifecycle commands
        <<"request_plugin_execution">>  -> execute_request_execution(Payload, State);
        <<"request_plugin_termination">> -> execute_request_termination(Payload, State);
        <<"confirm_container_up">>      -> execute_confirm_up(Payload);
        <<"confirm_container_down">>    -> execute_confirm_down(Payload);
        <<"start_oci_pull">>            -> execute_start_pull(Payload, S, State);
        <<"cancel_oci_pull">>           -> execute_cancel_pull(Payload, S);
        <<"complete_oci_pull">>         -> execute_complete_pull(Payload, S);
        %% In-VM model commands
        <<"extract_plugin_package">>    -> execute_extract_package(Payload, State);
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

execute_request_execution(_Payload, #plugin_state{status = S})
  when S band ?PLG_RUNNING =/= 0 ->
    {error, plugin_already_running};
execute_request_execution(Payload, State) ->
    {ok, Cmd} = request_plugin_execution_v1:from_map(Payload),
    convert_events(maybe_request_plugin_execution:handle(Cmd, State), fun plugin_execution_requested_v1:to_map/1).

execute_request_termination(Payload, State) ->
    {ok, Cmd} = request_plugin_termination_v1:from_map(Payload),
    convert_events(maybe_request_plugin_termination:handle(Cmd, State), fun plugin_termination_requested_v1:to_map/1).

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
    plugin_state:apply_event(State, Event).

%% --- Internal ---

get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
