%%% @doc Plugin aggregate state module (node context).
%%%
%%% Owns the plugin_state record shape, initial state creation,
%%% event folding (apply), and serialization.
%%% @end
-module(plugin_state).

-behaviour(evoq_state).

-include("plugin_status.hrl").
-include("plugin_state.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #plugin_state{}.
-export_type([state/0]).

%% --- evoq_state callbacks ---

-spec new(binary()) -> state().
new(_AggregateId) ->
    #plugin_state{status = 0}.

-spec apply_event(state(), map()) -> state().

apply_event(S, #{event_type := <<"plugin_installed_v1">>} = E)             -> apply_installed(E, S);
apply_event(S, #{event_type := <<"plugin_upgraded_v1">>} = E)              -> apply_upgraded(E, S);
apply_event(S, #{event_type := <<"plugin_removed_v1">>} = E)               -> apply_removed(E, S);
apply_event(S, #{event_type := <<"plugin_execution_started_v1">>} = E)     -> apply_started(E, S);
apply_event(S, #{event_type := <<"plugin_execution_stopped_v1">>} = E)     -> apply_stopped(E, S);
apply_event(S, #{event_type := <<"container_confirmed_up_v1">>})           -> apply_confirmed_up(S);
apply_event(S, #{event_type := <<"container_confirmed_down_v1">>})         -> apply_confirmed_down(S);
apply_event(S, #{event_type := <<"oci_pull_started_v1">>})                 -> apply_pull_started(S);
apply_event(S, #{event_type := <<"oci_pull_cancelled_v1">>})               -> apply_pull_cancelled(S);
apply_event(S, #{event_type := <<"oci_pull_completed_v1">>})               -> apply_pull_completed(S);
%% In-VM events
apply_event(S, #{event_type := <<"plugin_package_extracted_v1">>} = E)     -> apply_package_extracted(E, S);
apply_event(S, #{event_type := <<"plugin_activated_v1">>} = E)             -> apply_activated(E, S);
apply_event(S, #{event_type := <<"plugin_deactivated_v1">>} = E)           -> apply_deactivated(E, S);
apply_event(S, #{event_type := <<"plugin_load_confirmed_v1">>})            -> apply_load_confirmed(S);
apply_event(S, #{event_type := <<"plugin_unload_confirmed_v1">>})          -> apply_unload_confirmed(S);
%% Unknown — ignore
apply_event(S, _E) -> S.

-spec to_map(state()) -> map().
to_map(#plugin_state{} = S) ->
    #{
        plugin_id         => S#plugin_state.plugin_id,
        name              => S#plugin_state.name,
        plugin_type       => S#plugin_state.plugin_type,
        callback_module   => S#plugin_state.callback_module,
        oci_image         => S#plugin_state.oci_image,
        package_url       => S#plugin_state.package_url,
        installed_version => S#plugin_state.installed_version,
        license_id        => S#plugin_state.license_id,
        icon              => S#plugin_state.icon,
        group_name        => S#plugin_state.group_name,
        group_icon        => S#plugin_state.group_icon,
        installed_at      => S#plugin_state.installed_at,
        upgraded_at       => S#plugin_state.upgraded_at,
        removed_at        => S#plugin_state.removed_at,
        started_at        => S#plugin_state.started_at,
        stopped_at        => S#plugin_state.stopped_at,
        activated_at      => S#plugin_state.activated_at,
        deactivated_at    => S#plugin_state.deactivated_at,
        extracted_at      => S#plugin_state.extracted_at,
        status            => S#plugin_state.status
    }.

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

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, null} -> undefined;
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

%% @private Use new value if defined, otherwise keep existing.
coalesce(undefined, Existing) -> Existing;
coalesce(New, _Existing) -> New.
