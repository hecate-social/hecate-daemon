%%% @doc maybe_buy_license handler
%%% Business logic for purchasing a license (paid path).
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
    LicenseId = buy_license_v1:get_license_id(Cmd),
    case validate_command(LicenseId) of
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

validate_command(LicenseId) when is_binary(LicenseId), byte_size(LicenseId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_license_id}.

create_event(Cmd) ->
    license_bought_v1:new(#{
        license_id => buy_license_v1:get_license_id(Cmd),
        payment_reference => buy_license_v1:get_payment_reference(Cmd)
    }).
