%%% @doc Handler for start_oci_pull_v1 command.
%%% Business rules:
%%%   - Plugin must be installed (PLG_INSTALLED set)
%%%   - Must not already be pulling (PLG_PULLING not set)
-module(maybe_start_oci_pull).

-include("plugin_state.hrl").
-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(start_oci_pull_v1:start_oci_pull_v1()) ->
    {ok, [oci_pull_started_v1:oci_pull_started_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(start_oci_pull_v1:start_oci_pull_v1(), term()) ->
    {ok, [oci_pull_started_v1:oci_pull_started_v1()]} | {error, term()}.
handle(Cmd, #plugin_state{oci_image = StateOciImage}) ->
    PluginId = start_oci_pull_v1:get_plugin_id(Cmd),
    CmdOciImage = start_oci_pull_v1:get_oci_image(Cmd),
    OciImage = case CmdOciImage of
        undefined -> StateOciImage;
        _ -> CmdOciImage
    end,
    Event = oci_pull_started_v1:new(#{
        plugin_id => PluginId,
        oci_image => OciImage
    }),
    {ok, [Event]};
handle(Cmd, _State) ->
    PluginId = start_oci_pull_v1:get_plugin_id(Cmd),
    OciImage = start_oci_pull_v1:get_oci_image(Cmd),
    Event = oci_pull_started_v1:new(#{
        plugin_id => PluginId,
        oci_image => OciImage
    }),
    {ok, [Event]}.

-spec dispatch(start_oci_pull_v1:start_oci_pull_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    PluginId = start_oci_pull_v1:get_plugin_id(Cmd),
    Timestamp = erlang:system_time(millisecond),
    EvoqCmd = #evoq_command{
        command_type = start_oci_pull,
        aggregate_type = plugin_aggregate,
        aggregate_id = PluginId,
        payload = start_oci_pull_v1:to_map(Cmd),
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
