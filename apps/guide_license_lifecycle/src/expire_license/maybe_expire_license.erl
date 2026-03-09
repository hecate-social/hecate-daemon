%%% @doc maybe_expire_license handler
%%% Business logic for expiring a granted license.
-module(maybe_expire_license).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


%% @doc Handle expire_license_v1 command (business logic only)
-spec handle(expire_license_v1:expire_license_v1()) ->
    {ok, [license_expired_v1:license_expired_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(expire_license_v1:expire_license_v1(), term()) ->
    {ok, [license_expired_v1:license_expired_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    LicenseId = expire_license_v1:get_license_id(Cmd),
    case validate_command(LicenseId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(expire_license_v1:expire_license_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    LicenseId = expire_license_v1:get_license_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = expire_license,
        aggregate_type = license_aggregate,
        aggregate_id = LicenseId,
        payload = expire_license_v1:to_map(Cmd),
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

create_event(Cmd) ->
    license_expired_v1:new(#{
        license_id => expire_license_v1:get_license_id(Cmd)
    }).
