%%% @doc Merged projection: all plugin lifecycle events -> plugins ETS read model.
%%%
%%% Replaces 10 individual projections that each subscribed independently
%%% to the same ETS table, causing race conditions when events arrived
%%% before plugin_installed_v1 had created the entry.
%%%
%%% By handling ALL event types in a single projection, events are processed
%%% sequentially per stream, eliminating the race.
%%%
%%% Status bit flags:
%%%   INSTALLED      = 1
%%%   REMOVED        = 2
%%%   RUNNING        = 4
%%%   STOPPED        = 8
%%%   CONFIRMED_UP   = 16
%%%   CONFIRMED_DOWN = 32
%%%   PULLING        = 64
%%% @end
-module(plugin_lifecycle_to_plugins).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

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
     <<"oci_pull_completed_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = Event, _Metadata, State, RM) ->
    EventType = get_event_type(Event),
    do_project(EventType, Data, State, RM).

%% --- plugin_installed_v1: INSERT new plugin record ---

do_project(<<"plugin_installed_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    Plugin = #{
        plugin_id         => PluginId,
        name              => gf(name, Data),
        oci_image         => gf(oci_image, Data),
        installed_version => gf(installed_version, Data),
        license_id        => gf(license_id, Data),
        installed_at      => gf(installed_at, Data),
        upgraded_at       => undefined,
        removed_at        => undefined,
        started_at        => undefined,
        stopped_at        => undefined,
        status            => 1,
        status_label      => <<"Installed">>,
        icon              => gf(icon, Data),
        group_name        => gf(group_name, Data)
    },
    {ok, RM2} = evoq_read_model:put(PluginId, Plugin, RM),
    {ok, State, RM2};

%% --- plugin_upgraded_v1: UPDATE image, version, timestamp ---

do_project(<<"plugin_upgraded_v1">>, Data, State, RM) ->
    PluginId = gf(plugin_id, Data),
    case evoq_read_model:get(PluginId, RM) of
        {ok, Plugin} ->
            Updated = Plugin#{
                oci_image         => gf(oci_image, Data),
                installed_version => gf(installed_version, Data),
                upgraded_at       => gf(upgraded_at, Data)
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
            Updated = Plugin#{
                status       => S bor 2,
                status_label => <<"Removed">>,
                removed_at   => gf(removed_at, Data)
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
        {ok, #{status := S} = Plugin} ->
            Updated = Plugin#{
                status       => (S bor 4) band (bnot 8),
                status_label => <<"Starting">>,
                started_at   => gf(started_at, Data),
                stopped_at   => undefined
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
            Updated = Plugin#{
                status       => (S bor 8) band (bnot 4),
                status_label => <<"Stopped">>,
                stopped_at   => gf(stopped_at, Data)
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
            Updated = Plugin#{
                status       => (S bor 16) band (bnot 32) band (bnot 64),
                status_label => <<"Running">>
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
            Updated = Plugin#{
                status       => (S bor 32) band (bnot 16),
                status_label => <<"Stopped">>
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
            Updated = Plugin#{
                status       => S bor 64,
                status_label => <<"Downloading">>
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
            Updated = Plugin#{
                status       => S band (bnot 64),
                status_label => <<"Installed">>
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
            Updated = Plugin#{
                status       => S band (bnot 64),
                status_label => <<"Ready">>
            },
            {ok, RM2} = evoq_read_model:put(PluginId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- Unknown event type: skip ---

do_project(_Unknown, _Data, State, RM) ->
    {skip, State, RM}.

%% --- Helpers ---

get_event_type(#{event_type := T}) when is_binary(T) -> T;
get_event_type(#{<<"event_type">> := T}) when is_binary(T) -> T;
get_event_type(_) -> undefined.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
