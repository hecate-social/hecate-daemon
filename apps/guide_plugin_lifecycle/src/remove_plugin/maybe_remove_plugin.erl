%%% @doc maybe_remove_plugin handler (node context)
%%% Business logic for removing plugins from this node.
%%% Validates the command and dispatches via evoq.
-module(maybe_remove_plugin).

-include("plugin_state.hrl").
-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

%% @doc Handle remove_plugin_v1 command (business logic only)
-spec handle(remove_plugin_v1:remove_plugin_v1()) ->
    {ok, [plugin_removed_v1:plugin_removed_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(remove_plugin_v1:remove_plugin_v1(), term()) ->
    {ok, [plugin_removed_v1:plugin_removed_v1()]} | {error, term()}.
handle(Cmd, State) ->
    PluginId = remove_plugin_v1:get_plugin_id(Cmd),
    case validate_command(PluginId) of
        ok ->
            Event = create_event(Cmd, State),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(remove_plugin_v1:remove_plugin_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    PluginId = remove_plugin_v1:get_plugin_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = remove_plugin,
        aggregate_type = plugin_aggregate,
        aggregate_id = PluginId,
        payload = remove_plugin_v1:to_map(Cmd),
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

validate_command(PluginId) when is_binary(PluginId), byte_size(PluginId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_command}.

create_event(Cmd, #plugin_state{oci_image = OciImage}) ->
    plugin_removed_v1:new(#{
        plugin_id => remove_plugin_v1:get_plugin_id(Cmd),
        oci_image => OciImage
    });
create_event(Cmd, _State) ->
    plugin_removed_v1:new(#{
        plugin_id => remove_plugin_v1:get_plugin_id(Cmd),
        oci_image => undefined
    }).
