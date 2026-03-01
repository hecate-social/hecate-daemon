%%% @doc maybe_retract_license handler
%%% Business logic for retracting licenses (pull back to draft).
%%% Validates the command and dispatches via evoq.
-module(maybe_retract_license).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(retract_license_v1:retract_license_v1()) ->
    {ok, [license_retracted_v1:license_retracted_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(retract_license_v1:retract_license_v1(), term()) ->
    {ok, [license_retracted_v1:license_retracted_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    LicenseId = retract_license_v1:get_license_id(Cmd),
    case validate_command(LicenseId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(retract_license_v1:retract_license_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    LicenseId = retract_license_v1:get_license_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = retract_license,
        aggregate_type = license_aggregate,
        aggregate_id = LicenseId,
        payload = retract_license_v1:to_map(Cmd),
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

validate_command(LicenseId) when
    is_binary(LicenseId), byte_size(LicenseId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_license_id}.

create_event(Cmd) ->
    license_retracted_v1:new(#{
        license_id => retract_license_v1:get_license_id(Cmd)
    }).
