%%% @doc maybe_reject_offering_terms handler
%%% Business logic for rejecting offering terms.
-module(maybe_reject_offering_terms).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


%% @doc Handle reject_offering_terms_v1 command (business logic only)
-spec handle(reject_offering_terms_v1:reject_offering_terms_v1()) ->
    {ok, [offering_terms_rejected_v1:offering_terms_rejected_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(reject_offering_terms_v1:reject_offering_terms_v1(), term()) ->
    {ok, [offering_terms_rejected_v1:offering_terms_rejected_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    LicenseId = reject_offering_terms_v1:get_license_id(Cmd),
    case validate_command(LicenseId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(reject_offering_terms_v1:reject_offering_terms_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    LicenseId = reject_offering_terms_v1:get_license_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = reject_offering_terms,
        aggregate_type = license_aggregate,
        aggregate_id = LicenseId,
        payload = reject_offering_terms_v1:to_map(Cmd),
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
    offering_terms_rejected_v1:new(#{
        license_id => reject_offering_terms_v1:get_license_id(Cmd),
        reason => reject_offering_terms_v1:get_reason(Cmd)
    }).
