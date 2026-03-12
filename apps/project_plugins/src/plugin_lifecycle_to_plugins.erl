%%% @doc Merged projection: all plugin lifecycle events -> plugins ETS read model.
%%%
%%% Replaces 10 individual projections that each subscribed independently
%%% to the same ETS table, causing race conditions when events arrived
%%% before plugin_installed_v1 had created the entry.
%%%
%%% By handling ALL event types in a single projection, events are processed
%%% sequentially per stream, eliminating the race.
%%%
%%% Status bit flags defined in plugin_status.hrl:
%%%   ?PLG_INSTALLED      = 1
%%%   ?PLG_REMOVED        = 2
%%%   ?PLG_RUNNING        = 4
%%%   ?PLG_STOPPED        = 8
%%%   ?PLG_CONFIRMED_UP   = 16
%%%   ?PLG_CONFIRMED_DOWN = 32
%%%   ?PLG_PULLING        = 64
%%%   ?PLG_EXTRACTING     = 128
%%%   ?PLG_ACTIVATED      = 256
%%%   ?PLG_DEACTIVATED    = 512
%%% @end
-module(plugin_lifecycle_to_plugins).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4, available_actions/1]).

-include_lib("guide_plugin_lifecycle/include/plugin_status.hrl").

-define(TABLE, plugins).

interested_in() ->
    [<<"plugin_installed_v1">>,
     <<"plugin_upgraded_v1">>,
     <<"plugin_removed_v1">>,
     <<"plugin_execution_started_v1">>,
     <<"plugin_execution_stopped_v1">>,
     <<"container_confirmed_up_v1">>,
     <<"container_confirmed_down_v1">>,
     <<"oci_pull_started_v1">>,
     <<"oci_pull_cancelled_v1">>,
     <<"oci_pull_completed_v1">>,
     %% In-VM plugin events
     <<"plugin_package_extracted_v1">>,
     <<"plugin_activated_v1">>,
     <<"plugin_deactivated_v1">>,
     <<"plugin_load_confirmed_v1">>,
     <<"plugin_unload_confirmed_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = Event, _Metadata, State, RM) ->
    EventType = get_event_type(Event),
    do_project(EventType, Data, State, RM).

%% --- plugin_installed_v1: INSERT new plugin record ---

do_project(<<"plugin_installed_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    Name = gf(name, Data),
    DisplayName = case gf(display_name, Data) of
        undefined -> Name;
        DN -> DN
    end,
    Status = ?PLG_INSTALLED,
    Plugin = #{
        plugin_id         => PluginId,
        name              => Name,
        display_name      => DisplayName,
        plugin_type       => gf(plugin_type, Data, <<"container">>),
        oci_image         => gf(oci_image, Data),
        callback_module   => gf(callback_module, Data),
        package_url       => gf(package_url, Data),
        installed_version => gf(installed_version, Data),
        license_id        => gf(license_id, Data),
        installed_at      => gf(installed_at, Data),
        upgraded_at       => undefined,
        removed_at        => undefined,
        started_at        => undefined,
        stopped_at        => undefined,
        activated_at      => undefined,
        deactivated_at    => undefined,
        extracted_at      => undefined,
        status            => Status,
        status_label      => <<"Installed">>,
        available_actions => available_actions(Status),
        icon              => gf(icon, Data),
        group_name        => gf(group_name, Data),
        group_icon        => gf(group_icon, Data),
        description       => gf(description, Data)
    },
    {ok, RM2} = evoq_read_model:put(PluginId, Plugin, RM),
    {ok, State, RM2};

%% --- plugin_upgraded_v1: UPDATE image, version, timestamp ---

do_project(<<"plugin_upgraded_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    case evoq_read_model:get(PluginId, RM) of
        {ok, #{status := S} = Plugin} ->
            Updated = Plugin#{
                oci_image         => coalesce(gf(oci_image, Data), maps:get(oci_image, Plugin, undefined)),
                package_url       => coalesce(gf(package_url, Data), maps:get(package_url, Plugin, undefined)),
                plugin_type       => coalesce(gf(plugin_type, Data), maps:get(plugin_type, Plugin, undefined)),
                installed_version => gf(installed_version, Data),
                upgraded_at       => gf(upgraded_at, Data),
                icon              => coalesce(gf(icon, Data), maps:get(icon, Plugin, undefined)),
                group_name        => coalesce(gf(group_name, Data), maps:get(group_name, Plugin, undefined)),
                group_icon        => coalesce(gf(group_icon, Data), maps:get(group_icon, Plugin, undefined)),
                display_name      => coalesce(gf(display_name, Data), maps:get(display_name, Plugin, undefined)),
                description       => coalesce(gf(description, Data), maps:get(description, Plugin, undefined)),
                available_actions => available_actions(S)
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- plugin_removed_v1: set REMOVED(2) flag ---

do_project(<<"plugin_removed_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    case evoq_read_model:get(PluginId, RM) of
        {ok, #{status := S} = Plugin} ->
            NewStatus = evoq_bit_flags:set(S, ?PLG_REMOVED),
            Updated = Plugin#{
                status            => NewStatus,
                status_label      => <<"Removed">>,
                available_actions => available_actions(NewStatus),
                removed_at        => gf(removed_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- plugin_execution_started_v1: set RUNNING(4), clear STOPPED(8) ---

do_project(<<"plugin_execution_started_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    case evoq_read_model:get(PluginId, RM) of
        {ok, #{status := S, status_label := <<"Running">>} = Plugin} ->
            %% Already running (e.g. in-VM plugin) — update flags but don't regress label
            NewStatus = evoq_bit_flags:set(evoq_bit_flags:unset(S, ?PLG_STOPPED), ?PLG_RUNNING),
            Updated = Plugin#{
                status            => NewStatus,
                available_actions => available_actions(NewStatus),
                started_at        => gf(started_at, Data),
                stopped_at        => undefined
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {ok, #{status := S} = Plugin} ->
            NewStatus = evoq_bit_flags:set(evoq_bit_flags:unset(S, ?PLG_STOPPED), ?PLG_RUNNING),
            Updated = Plugin#{
                status            => NewStatus,
                status_label      => <<"Starting">>,
                available_actions => available_actions(NewStatus),
                started_at        => gf(started_at, Data),
                stopped_at        => undefined
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- plugin_execution_stopped_v1: set STOPPED(8), clear RUNNING(4) ---

do_project(<<"plugin_execution_stopped_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    case evoq_read_model:get(PluginId, RM) of
        {ok, #{status := S} = Plugin} ->
            NewStatus = evoq_bit_flags:set(evoq_bit_flags:unset(S, ?PLG_RUNNING), ?PLG_STOPPED),
            Updated = Plugin#{
                status            => NewStatus,
                status_label      => <<"Stopped">>,
                available_actions => available_actions(NewStatus),
                stopped_at        => gf(stopped_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- container_confirmed_up_v1: set CONFIRMED_UP(16), clear CONFIRMED_DOWN(32) and PULLING(64) ---

do_project(<<"container_confirmed_up_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    case evoq_read_model:get(PluginId, RM) of
        {ok, #{status := S} = Plugin} ->
            NewStatus = evoq_bit_flags:set(evoq_bit_flags:unset_all(S, [?PLG_CONFIRMED_DOWN, ?PLG_PULLING]), ?PLG_CONFIRMED_UP),
            Updated = Plugin#{
                status            => NewStatus,
                status_label      => <<"Running">>,
                available_actions => available_actions(NewStatus)
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- container_confirmed_down_v1: set CONFIRMED_DOWN(32), clear CONFIRMED_UP(16) ---

do_project(<<"container_confirmed_down_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    case evoq_read_model:get(PluginId, RM) of
        {ok, #{status := S} = Plugin} ->
            NewStatus = evoq_bit_flags:set(evoq_bit_flags:unset(S, ?PLG_CONFIRMED_UP), ?PLG_CONFIRMED_DOWN),
            Updated = Plugin#{
                status            => NewStatus,
                status_label      => <<"Stopped">>,
                available_actions => available_actions(NewStatus)
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- oci_pull_started_v1: set PULLING(64) ---

do_project(<<"oci_pull_started_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    case evoq_read_model:get(PluginId, RM) of
        {ok, #{status := S} = Plugin} ->
            NewStatus = evoq_bit_flags:set(S, ?PLG_PULLING),
            Updated = Plugin#{
                status            => NewStatus,
                status_label      => <<"Downloading">>,
                available_actions => available_actions(NewStatus)
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- oci_pull_cancelled_v1: clear PULLING(64) ---

do_project(<<"oci_pull_cancelled_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    case evoq_read_model:get(PluginId, RM) of
        {ok, #{status := S} = Plugin} ->
            NewStatus = evoq_bit_flags:unset(S, ?PLG_PULLING),
            Updated = Plugin#{
                status            => NewStatus,
                status_label      => <<"Installed">>,
                available_actions => available_actions(NewStatus)
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- oci_pull_completed_v1: clear PULLING(64), set Ready ---

do_project(<<"oci_pull_completed_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    case evoq_read_model:get(PluginId, RM) of
        {ok, #{status := S} = Plugin} ->
            NewStatus = evoq_bit_flags:unset(S, ?PLG_PULLING),
            Updated = Plugin#{
                status            => NewStatus,
                status_label      => <<"Ready">>,
                available_actions => available_actions(NewStatus)
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- plugin_package_extracted_v1: set EXTRACTING flag (transient), record timestamp ---

do_project(<<"plugin_package_extracted_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    case evoq_read_model:get(PluginId, RM) of
        {ok, #{status := S} = Plugin} ->
            Updated = Plugin#{
                extracted_at      => gf(extracted_at, Data),
                callback_module   => gf(callback_module, Data, maps:get(callback_module, Plugin, undefined)),
                status_label      => <<"Extracted">>,
                available_actions => available_actions(S)
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- plugin_activated_v1: set ACTIVATED(256), clear DEACTIVATED(512) ---

do_project(<<"plugin_activated_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    case evoq_read_model:get(PluginId, RM) of
        {ok, #{status := S} = Plugin} ->
            NewStatus = evoq_bit_flags:set(evoq_bit_flags:unset(S, ?PLG_DEACTIVATED), ?PLG_ACTIVATED),
            Updated = Plugin#{
                status            => NewStatus,
                status_label      => <<"Activating">>,
                available_actions => available_actions(NewStatus),
                callback_module   => gf(callback_module, Data),
                activated_at      => gf(activated_at, Data),
                deactivated_at    => undefined
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- plugin_deactivated_v1: set DEACTIVATED(512), clear ACTIVATED(256) ---

do_project(<<"plugin_deactivated_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    case evoq_read_model:get(PluginId, RM) of
        {ok, #{status := S} = Plugin} ->
            NewStatus = evoq_bit_flags:set(evoq_bit_flags:unset(S, ?PLG_ACTIVATED), ?PLG_DEACTIVATED),
            Updated = Plugin#{
                status            => NewStatus,
                status_label      => <<"Deactivated">>,
                available_actions => available_actions(NewStatus),
                deactivated_at    => gf(deactivated_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- plugin_load_confirmed_v1: ACTIVATED confirmed running ---

do_project(<<"plugin_load_confirmed_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    logger:info("[projection] plugin_load_confirmed_v1 received for ~s", [PluginId]),
    case evoq_read_model:get(PluginId, RM) of
        {ok, #{status := S} = Plugin} ->
            Updated = Plugin#{
                status_label      => <<"Running">>,
                available_actions => available_actions(S)
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            logger:info("[projection] status_label set to Running for ~s", [PluginId]),
            {ok, State, RM2};
        {error, not_found} ->
            logger:warning("[projection] plugin_load_confirmed_v1 for ~s: not_found in read model", [PluginId]),
            {skip, State, RM}
    end;

%% --- plugin_unload_confirmed_v1: DEACTIVATED confirmed unloaded ---

do_project(<<"plugin_unload_confirmed_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    case evoq_read_model:get(PluginId, RM) of
        {ok, #{status := S} = Plugin} ->
            Updated = Plugin#{
                status_label      => <<"Stopped">>,
                available_actions => available_actions(S)
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- Unknown event type: skip ---

do_project(_Unknown, _Data, State, RM) ->
    {skip, State, RM}.

%% --- Available Actions ---

%% @doc Compute user-facing actions available for a given plugin status.
available_actions(0) ->
    [<<"install">>];
available_actions(Status) ->
    HasRemoved     = evoq_bit_flags:has(Status, ?PLG_REMOVED),
    HasInstalled   = evoq_bit_flags:has(Status, ?PLG_INSTALLED),
    HasPulling     = evoq_bit_flags:has(Status, ?PLG_PULLING),
    HasExtracting  = evoq_bit_flags:has(Status, ?PLG_EXTRACTING),
    HasRunning     = evoq_bit_flags:has(Status, ?PLG_RUNNING),
    HasConfirmedUp = evoq_bit_flags:has(Status, ?PLG_CONFIRMED_UP),
    HasConfirmedDn = evoq_bit_flags:has(Status, ?PLG_CONFIRMED_DOWN),
    HasStopped     = evoq_bit_flags:has(Status, ?PLG_STOPPED),
    HasActivated   = evoq_bit_flags:has(Status, ?PLG_ACTIVATED),
    HasDeactivated = evoq_bit_flags:has(Status, ?PLG_DEACTIVATED),
    if
        HasRemoved, not HasInstalled ->
            [<<"install">>];
        HasPulling ->
            [];
        HasExtracting ->
            [];
        %% In-VM plugins: activated = running
        HasActivated, not HasDeactivated ->
            [<<"stop">>, <<"upgrade">>, <<"remove">>];
        %% Container plugins: confirmed up = running
        HasConfirmedUp ->
            [<<"stop">>, <<"upgrade">>, <<"remove">>];
        HasInstalled, (HasConfirmedDn orelse HasStopped orelse HasDeactivated orelse not HasRunning) ->
            [<<"start">>, <<"upgrade">>, <<"remove">>];
        HasInstalled, HasRunning ->
            [];
        true ->
            []
    end.

%% --- Helpers ---

get_event_type(#{event_type := T}) when is_binary(T) -> T;
get_event_type(#{<<"event_type">> := T}) when is_binary(T) -> T;
get_event_type(_) -> undefined.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
gf(Key, Data, Default) -> hecate_api_utils:get_field(Key, Data, Default).

coalesce(undefined, Existing) -> Existing;
coalesce(New, _Existing) -> New.

