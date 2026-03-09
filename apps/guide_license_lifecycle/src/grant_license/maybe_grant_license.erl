%%% @doc maybe_grant_license handler
%%% Business logic for granting (activating) a license.
%%% Receives aggregate State to echo install-relevant fields into the event.
-module(maybe_grant_license).

-include_lib("evoq/include/evoq.hrl").
-include("license_state.hrl").

-export([handle/1, handle/2, dispatch/1]).


%% @doc Handle grant_license_v1 command (business logic only)
-spec handle(grant_license_v1:grant_license_v1()) ->
    {ok, [license_granted_v1:license_granted_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state — echoes install fields from aggregate into event
-spec handle(grant_license_v1:grant_license_v1(), term()) ->
    {ok, [license_granted_v1:license_granted_v1()]} | {error, term()}.
handle(Cmd, State) ->
    LicenseId = grant_license_v1:get_license_id(Cmd),
    case validate_command(LicenseId) of
        ok ->
            Event = create_event(Cmd, State),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(grant_license_v1:grant_license_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    LicenseId = grant_license_v1:get_license_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = grant_license,
        aggregate_type = license_aggregate,
        aggregate_id = LicenseId,
        payload = grant_license_v1:to_map(Cmd),
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

validate_command(LicenseId) when is_binary(LicenseId), byte_size(LicenseId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_license_id}.

create_event(Cmd, #license_state{} = State) ->
    license_granted_v1:new(#{
        license_id   => grant_license_v1:get_license_id(Cmd),
        grant_reason => grant_license_v1:get_grant_reason(Cmd),
        plugin_id    => State#license_state.plugin_id,
        plugin_name  => State#license_state.plugin_name,
        oci_image    => State#license_state.oci_image,
        version      => State#license_state.version,
        icon         => State#license_state.icon,
        group_name   => State#license_state.group_name,
        plugin_type  => State#license_state.plugin_type,
        callback_module => State#license_state.callback_module,
        package_url  => State#license_state.package_url
    });
create_event(Cmd, _State) ->
    license_granted_v1:new(#{
        license_id   => grant_license_v1:get_license_id(Cmd),
        grant_reason => grant_license_v1:get_grant_reason(Cmd)
    }).
