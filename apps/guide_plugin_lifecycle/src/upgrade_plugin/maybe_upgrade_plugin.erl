%%% @doc maybe_upgrade_plugin handler (node context)
%%% Business logic for upgrading plugins on this node.
%%% Validates the command and dispatches via evoq.
%%%
%%% Supports both plugin types:
%%%   container: validates oci_image is present
%%%   in_vm:     validates package_url is present
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
    PackageUrl = upgrade_plugin_v1:get_package_url(Cmd),
    case validate_command(PluginId, OciImage, PackageUrl) of
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

%% Must have plugin_id AND (oci_image OR package_url)
validate_command(PluginId, _OciImage, _PackageUrl) when
    not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, invalid_command};
validate_command(_PluginId, OciImage, PackageUrl) ->
    HasOci = is_binary(OciImage) andalso byte_size(OciImage) > 0,
    HasPkg = is_binary(PackageUrl) andalso byte_size(PackageUrl) > 0,
    case HasOci orelse HasPkg of
        true -> ok;
        false -> {error, missing_oci_image_or_package_url}
    end.

create_event(Cmd) ->
    plugin_upgraded_v1:new(#{
        plugin_id         => upgrade_plugin_v1:get_plugin_id(Cmd),
        oci_image         => upgrade_plugin_v1:get_oci_image(Cmd),
        package_url       => upgrade_plugin_v1:get_package_url(Cmd),
        plugin_type       => upgrade_plugin_v1:get_plugin_type(Cmd),
        installed_version => upgrade_plugin_v1:get_installed_version(Cmd),
        icon              => upgrade_plugin_v1:get_icon(Cmd),
        group_name        => upgrade_plugin_v1:get_group_name(Cmd),
        group_icon        => upgrade_plugin_v1:get_group_icon(Cmd),
        display_name      => upgrade_plugin_v1:get_display_name(Cmd),
        description       => upgrade_plugin_v1:get_description(Cmd)
    }).
