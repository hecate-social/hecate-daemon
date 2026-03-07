%%% @doc Handler for cancel_container_pull_v1 command.
%%% Business rules:
%%%   - Plugin must be pulling (PLG_PULLING set)
-module(maybe_cancel_container_pull).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(cancel_container_pull_v1:cancel_container_pull_v1()) ->
    {ok, [container_pull_cancelled_v1:container_pull_cancelled_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(cancel_container_pull_v1:cancel_container_pull_v1(), term()) ->
    {ok, [container_pull_cancelled_v1:container_pull_cancelled_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    PluginId = cancel_container_pull_v1:get_plugin_id(Cmd),
    Event = container_pull_cancelled_v1:new(#{plugin_id => PluginId}),
    {ok, [Event]}.

-spec dispatch(cancel_container_pull_v1:cancel_container_pull_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    PluginId = cancel_container_pull_v1:get_plugin_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = cancel_container_pull,
        aggregate_type = plugin_aggregate,
        aggregate_id = PluginId,
        payload = cancel_container_pull_v1:to_map(Cmd),
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
