%%% @doc Handler for confirm_plugin_loaded_v1 command.
%%% Business rules:
%%%   - Plugin must have been installed
%%%   - Idempotent: if already confirmed loaded, succeeds silently (no event)
-module(maybe_confirm_plugin_loaded).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(confirm_plugin_loaded_v1:confirm_plugin_loaded_v1()) ->
    {ok, [plugin_load_confirmed_v1:plugin_load_confirmed_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(confirm_plugin_loaded_v1:confirm_plugin_loaded_v1(), term()) ->
    {ok, [plugin_load_confirmed_v1:plugin_load_confirmed_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    PluginId = confirm_plugin_loaded_v1:get_plugin_id(Cmd),
    Event = plugin_load_confirmed_v1:new(#{plugin_id => PluginId}),
    {ok, [Event]}.

-spec dispatch(confirm_plugin_loaded_v1:confirm_plugin_loaded_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    PluginId = confirm_plugin_loaded_v1:get_plugin_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = confirm_plugin_loaded,
        aggregate_type = plugin_aggregate,
        aggregate_id = PluginId,
        payload = confirm_plugin_loaded_v1:to_map(Cmd),
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
