%%% @doc maybe_amend_license_pricing handler
%%% Business logic for amending pricing on a license.
%%% Validates at least one pricing field is provided.
-module(maybe_amend_license_pricing).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(amend_license_pricing_v1:amend_license_pricing_v1()) ->
    {ok, [license_pricing_amended_v1:license_pricing_amended_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(amend_license_pricing_v1:amend_license_pricing_v1(), term()) ->
    {ok, [license_pricing_amended_v1:license_pricing_amended_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    case amend_license_pricing_v1:validate(Cmd) of
        {ok, _} ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(amend_license_pricing_v1:amend_license_pricing_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    LicenseId = amend_license_pricing_v1:get_license_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = amend_license_pricing,
        aggregate_type = license_aggregate,
        aggregate_id = LicenseId,
        payload = amend_license_pricing_v1:to_map(Cmd),
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

create_event(Cmd) ->
    license_pricing_amended_v1:new(#{
        license_id      => amend_license_pricing_v1:get_license_id(Cmd),
        selling_formula => amend_license_pricing_v1:get_selling_formula(Cmd),
        license_type    => amend_license_pricing_v1:get_license_type(Cmd),
        fee_cents       => amend_license_pricing_v1:get_fee_cents(Cmd),
        fee_currency    => amend_license_pricing_v1:get_fee_currency(Cmd),
        duration_days   => amend_license_pricing_v1:get_duration_days(Cmd),
        node_limit      => amend_license_pricing_v1:get_node_limit(Cmd)
    }).
