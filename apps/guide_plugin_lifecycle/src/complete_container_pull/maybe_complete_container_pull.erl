%%% @doc Handler for complete_container_pull_v1 command.
%%% Business rules:
%%%   - Plugin must be pulling (PLG_PULLING set)
-module(maybe_complete_container_pull).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(complete_container_pull_v1:complete_container_pull_v1()) ->
    {ok, [container_pull_completed_v1:container_pull_completed_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(complete_container_pull_v1:complete_container_pull_v1(), term()) ->
    {ok, [container_pull_completed_v1:container_pull_completed_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    PluginId = complete_container_pull_v1:get_plugin_id(Cmd),
    Event = container_pull_completed_v1:new(#{plugin_id => PluginId}),
    {ok, [Event]}.

-spec dispatch(complete_container_pull_v1:complete_container_pull_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    PluginId = complete_container_pull_v1:get_plugin_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = complete_container_pull,
        aggregate_type = plugin_aggregate,
        aggregate_id = PluginId,
        payload = complete_container_pull_v1:to_map(Cmd),
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
