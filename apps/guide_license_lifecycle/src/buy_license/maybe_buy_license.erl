%%% @doc maybe_buy_license handler
%%% Business logic for buying plugin licenses.
%%% Validates the command and dispatches via evoq.
-module(maybe_buy_license).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


%% @doc Handle buy_license_v1 command (business logic only)
-spec handle(buy_license_v1:buy_license_v1()) ->
    {ok, [license_bought_v1:license_bought_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(buy_license_v1:buy_license_v1(), term()) ->
    {ok, [license_bought_v1:license_bought_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    UserId = buy_license_v1:get_user_id(Cmd),
    PluginId = buy_license_v1:get_plugin_id(Cmd),
    case validate_command(UserId, PluginId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(buy_license_v1:buy_license_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    LicenseId = buy_license_v1:get_license_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = buy_license,
        aggregate_type = license_aggregate,
        aggregate_id = LicenseId,
        payload = buy_license_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => license_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => licenses_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(UserId, PluginId) when
    is_binary(UserId), byte_size(UserId) > 0,
    is_binary(PluginId), byte_size(PluginId) > 0 ->
    ok;
validate_command(UserId, _PluginId) when
    not is_binary(UserId); byte_size(UserId) =:= 0 ->
    {error, invalid_user_id};
validate_command(_UserId, _PluginId) ->
    {error, invalid_plugin_id}.

create_event(Cmd) ->
    license_bought_v1:new(#{
        license_id => buy_license_v1:get_license_id(Cmd),
        user_id => buy_license_v1:get_user_id(Cmd),
        plugin_id => buy_license_v1:get_plugin_id(Cmd),
        plugin_name => buy_license_v1:get_plugin_name(Cmd),
        oci_image => buy_license_v1:get_oci_image(Cmd)
    }).
