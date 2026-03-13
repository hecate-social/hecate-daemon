%%% @doc Process Manager: license_bought_v1 -> grant_license_v1
%%%
%%% When a consumer completes payment, auto-grant the license.
%%% @end
-module(on_license_bought_grant_license).
-behaviour(evoq_event_handler).
-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"license_bought_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    LicenseId = hecate_api_utils:get_field(license_id, Data),
    logger:info("[PM] Payment received, auto-granting license ~s", [LicenseId]),
    case grant_license_v1:new(#{license_id => LicenseId, grant_reason => <<"payment_received">>}) of
        {ok, Cmd} ->
            case maybe_grant_license:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[PM] License ~s granted (paid path)", [LicenseId]);
                {error, Reason} ->
                    logger:error("[PM] Failed to grant license ~s: ~p", [LicenseId, Reason])
            end;
        {error, Reason} ->
            logger:error("[PM] Failed to create grant command for ~s: ~p", [LicenseId, Reason])
    end,
    {ok, State}.
