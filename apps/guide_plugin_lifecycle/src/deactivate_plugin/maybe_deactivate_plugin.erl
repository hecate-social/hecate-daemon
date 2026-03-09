%%% @doc Handler for deactivate_plugin_v1 command.
%%% Business rules:
%%%   - Plugin must exist
%%%   - Unloads in-VM plugin code from the BEAM
-module(maybe_deactivate_plugin).

-include("plugin_state.hrl").
-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(deactivate_plugin_v1:deactivate_plugin_v1()) ->
    {ok, [plugin_deactivated_v1:plugin_deactivated_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(deactivate_plugin_v1:deactivate_plugin_v1(), term()) ->
    {ok, [plugin_deactivated_v1:plugin_deactivated_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    PluginId = deactivate_plugin_v1:get_plugin_id(Cmd),
    Event = plugin_deactivated_v1:new(#{plugin_id => PluginId}),
    {ok, [Event]}.

-spec dispatch(deactivate_plugin_v1:deactivate_plugin_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    PluginId = deactivate_plugin_v1:get_plugin_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = deactivate_plugin,
        aggregate_type = plugin_aggregate,
        aggregate_id = PluginId,
        payload = deactivate_plugin_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => plugin_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },
    Opts = #{
        store_id => plugins_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    evoq_dispatcher:dispatch(EvoqCmd, Opts).
