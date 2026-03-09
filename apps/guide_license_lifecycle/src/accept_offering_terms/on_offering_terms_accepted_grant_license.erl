%%% @doc Process Manager: offering_terms_accepted_v1 -> grant_license_v1
%%%
%%% When a consumer accepts offering terms for a FREE offering
%%% (fee_cents = 0 or undefined), auto-grant the license.
%%% Paid offerings go through the buy_license path instead.
%%% @end
-module(on_offering_terms_accepted_grant_license).
-behaviour(evoq_event_handler).
-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"offering_terms_accepted_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    LicenseId = hecate_api_utils:get_field(license_id, Data),
    FeeCents = hecate_api_utils:get_field(fee_cents, Data),
    case is_free(FeeCents) of
        true ->
            logger:info("[PM] Free offering accepted, auto-granting license ~s", [LicenseId]),
            case grant_license_v1:new(#{license_id => LicenseId, grant_reason => <<"free_offering">>}) of
                {ok, Cmd} ->
                    case maybe_grant_license:dispatch(Cmd) of
                        {ok, _, _} ->
                            logger:info("[PM] License ~s granted (free path)", [LicenseId]);
                        {error, Reason} ->
                            logger:error("[PM] Failed to grant license ~s: ~p", [LicenseId, Reason])
                    end;
                {error, Reason} ->
                    logger:error("[PM] Failed to create grant command for ~s: ~p", [LicenseId, Reason])
            end;
        false ->
            logger:info("[PM] Paid offering accepted for ~s, awaiting buy_license", [LicenseId])
    end,
    {ok, State}.

is_free(undefined) -> true;
is_free(0) -> true;
is_free(N) when is_integer(N), N > 0 -> false;
is_free(_) -> true.
