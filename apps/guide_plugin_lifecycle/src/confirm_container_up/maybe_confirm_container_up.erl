%%% @doc Handler for confirm_container_up_v1 command.
%%% Business rules:
%%%   - Plugin must be installed
%%%   - Idempotent: if already confirmed up, succeeds silently (no event)
-module(maybe_confirm_container_up).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(confirm_container_up_v1:confirm_container_up_v1()) ->
    {ok, [container_confirmed_up_v1:container_confirmed_up_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(confirm_container_up_v1:confirm_container_up_v1(), term()) ->
    {ok, [container_confirmed_up_v1:container_confirmed_up_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    PluginId = confirm_container_up_v1:get_plugin_id(Cmd),
    Event = container_confirmed_up_v1:new(#{plugin_id => PluginId}),
    {ok, [Event]}.

-spec dispatch(confirm_container_up_v1:confirm_container_up_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    PluginId = confirm_container_up_v1:get_plugin_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = confirm_container_up,
        aggregate_type = plugin_aggregate,
        aggregate_id = PluginId,
        payload = confirm_container_up_v1:to_map(Cmd),
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
