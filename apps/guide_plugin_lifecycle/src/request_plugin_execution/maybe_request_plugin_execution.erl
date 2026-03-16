%%% @doc Handler for request_plugin_execution_v1 command.
%%% Business rules:
%%%   - Plugin must be installed (not removed)
%%%   - Plugin must not already be running
-module(maybe_request_plugin_execution).

-include("plugin_state.hrl").
-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(request_plugin_execution_v1:request_plugin_execution_v1()) ->
    {ok, [plugin_execution_requested_v1:plugin_execution_requested_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(request_plugin_execution_v1:request_plugin_execution_v1(), term()) ->
    {ok, [plugin_execution_requested_v1:plugin_execution_requested_v1()]} | {error, term()}.
handle(Cmd, #plugin_state{oci_image = OciImage, plugin_type = PluginType,
                          callback_module = CallbackModule, name = Name}) ->
    PluginId = request_plugin_execution_v1:get_plugin_id(Cmd),
    Event = plugin_execution_requested_v1:new(#{
        plugin_id => PluginId,
        oci_image => OciImage,
        plugin_type => PluginType,
        callback_module => CallbackModule,
        name => Name
    }),
    {ok, [Event]};
handle(Cmd, _State) ->
    PluginId = request_plugin_execution_v1:get_plugin_id(Cmd),
    Event = plugin_execution_requested_v1:new(#{plugin_id => PluginId}),
    {ok, [Event]}.

-spec dispatch(request_plugin_execution_v1:request_plugin_execution_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    PluginId = request_plugin_execution_v1:get_plugin_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = request_plugin_execution,
        aggregate_type = plugin_aggregate,
        aggregate_id = PluginId,
        payload = request_plugin_execution_v1:to_map(Cmd),
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
