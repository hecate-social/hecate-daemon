#!/usr/bin/env bash
set -euo pipefail

# Generate per-event web emitters for project_plugins.
# Each event gets its own desk directory and emitter module.

BASE="$(cd "$(dirname "$0")/.." && pwd)/apps/project_plugins/src"

EVENTS=(
    plugin_installed_v1
    plugin_upgraded_v1
    plugin_removed_v1
    plugin_execution_requested_v1
    plugin_termination_requested_v1
    container_confirmed_up_v1
    container_confirmed_down_v1
    oci_pull_started_v1
    oci_pull_cancelled_v1
    oci_pull_completed_v1
    plugin_package_extracted_v1
    plugin_load_confirmed_v1
    plugin_unload_confirmed_v1
)

for EVENT in "${EVENTS[@]}"; do
    # Desk dir = event name without version
    DESK="${EVENT%_v1}"
    MODULE="${EVENT}_to_web"
    DIR="${BASE}/${DESK}"

    mkdir -p "${DIR}"

    cat > "${DIR}/${MODULE}.erl" <<ERLANG
%%% @doc Emitter: ${EVENT} -> web frontend via SSE.
%%%
%%% Subscribes to ${EVENT} and broadcasts the current plugin
%%% state to connected web clients via hecate_web_events.
%%% @end
-module(${MODULE}).
-behaviour(evoq_event_handler).
-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"${EVENT}">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, #{data := Data}, _Metadata, State) ->
    PluginId = hecate_api_utils:get_field(plugin_id, Data),
    case project_plugins_store:get(PluginId) of
        {ok, Plugin} ->
            hecate_web_events:broadcast(plugin_status_changed, #{
                plugin_id         => PluginId,
                name              => maps:get(name, Plugin, PluginId),
                status            => maps:get(status, Plugin, 0),
                status_label      => maps:get(status_label, Plugin, <<>>),
                available_actions => maps:get(available_actions, Plugin, [])
            });
        _ ->
            ok
    end,
    {ok, State};
handle_event(_EventType, _Event, _Metadata, State) ->
    {ok, State}.
ERLANG

    echo "Created ${DIR}/${MODULE}.erl"
done
