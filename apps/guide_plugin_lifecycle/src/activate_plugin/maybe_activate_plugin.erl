%%% @doc Handler for activate_plugin_v1 command.
%%% Business rules:
%%%   - Plugin must be installed
%%%   - Plugin must be an in-VM plugin (has callback_module)
-module(maybe_activate_plugin).

-include("plugin_state.hrl").
-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(activate_plugin_v1:activate_plugin_v1()) ->
    {ok, [plugin_activated_v1:plugin_activated_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(activate_plugin_v1:activate_plugin_v1(), term()) ->
    {ok, [plugin_activated_v1:plugin_activated_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    PluginId = activate_plugin_v1:get_plugin_id(Cmd),
    CallbackModule = activate_plugin_v1:get_callback_module(Cmd),
    Event = plugin_activated_v1:new(#{plugin_id => PluginId, callback_module => CallbackModule}),
    {ok, [Event]}.

-spec dispatch(activate_plugin_v1:activate_plugin_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    PluginId = activate_plugin_v1:get_plugin_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = activate_plugin,
        aggregate_type = plugin_aggregate,
        aggregate_id = PluginId,
        payload = activate_plugin_v1:to_map(Cmd),
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
