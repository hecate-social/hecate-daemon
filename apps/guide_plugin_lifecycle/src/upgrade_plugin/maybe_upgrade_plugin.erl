%%% @doc maybe_upgrade_plugin handler (node context)
%%% Business logic for upgrading plugins on this node.
%%% Validates the command and dispatches via evoq.
-module(maybe_upgrade_plugin).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

%% @doc Handle upgrade_plugin_v1 command (business logic only)
-spec handle(upgrade_plugin_v1:upgrade_plugin_v1()) ->
    {ok, [plugin_upgraded_v1:plugin_upgraded_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(upgrade_plugin_v1:upgrade_plugin_v1(), term()) ->
    {ok, [plugin_upgraded_v1:plugin_upgraded_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    PluginId = upgrade_plugin_v1:get_plugin_id(Cmd),
    OciImage = upgrade_plugin_v1:get_oci_image(Cmd),
    case validate_command(PluginId, OciImage) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(upgrade_plugin_v1:upgrade_plugin_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    PluginId = upgrade_plugin_v1:get_plugin_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = upgrade_plugin,
        aggregate_type = plugin_aggregate,
        aggregate_id = PluginId,
        payload = upgrade_plugin_v1:to_map(Cmd),
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

%% Internal

validate_command(PluginId, OciImage) when
    is_binary(PluginId), byte_size(PluginId) > 0,
    is_binary(OciImage), byte_size(OciImage) > 0 ->
    ok;
validate_command(_, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    plugin_upgraded_v1:new(#{
        plugin_id         => upgrade_plugin_v1:get_plugin_id(Cmd),
        oci_image         => upgrade_plugin_v1:get_oci_image(Cmd),
        installed_version => upgrade_plugin_v1:get_installed_version(Cmd)
    }).
