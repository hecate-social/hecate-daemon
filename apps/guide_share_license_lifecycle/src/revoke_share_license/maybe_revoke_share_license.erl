%%% @doc Handler for revoke_share_license_v1.
%%%
%%% Validates the license_id is present, returns the event for evoq to
%%% persist against `issued-license-{license_id}`. Aggregate guards
%%% enforce: must be SL_ISSUED, must not be already SL_REVOKED.
%%% @end
-module(maybe_revoke_share_license).

-export([handle/1, handle_from_map/1, dispatch/1, dispatch/2]).

-dialyzer({nowarn_function, [dispatch/1, dispatch/2]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{license_id := _} = Payload) ->
    RevokedAt = maps:get(revoked_at, Payload, erlang:system_time(millisecond)),
    {ok, Event} = share_license_revoked_v1:new(Payload#{revoked_at => RevokedAt}),
    {ok, [share_license_revoked_v1:to_map(Event)]};
handle_from_map(_) ->
    {error, missing_fields}.

-spec handle(revoke_share_license_v1:revoke_share_license_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Cmd) ->
    handle_from_map(revoke_share_license_v1:to_map(Cmd)).

-spec dispatch(revoke_share_license_v1:revoke_share_license_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    dispatch(Cmd, #{}).

-spec dispatch(revoke_share_license_v1:revoke_share_license_v1(), map()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd, Extras) ->
    Payload = maps:merge(revoke_share_license_v1:to_map(Cmd), Extras),
    LicenseId = maps:get(license_id, Payload),
    StreamId  = issued_license_aggregate:stream_id(LicenseId),
    EvoqCmd = #evoq_command{
        command_type   = revoke_share_license_v1,
        aggregate_type = issued_license_aggregate,
        aggregate_id   = StreamId,
        payload        = Payload#{command_type => revoke_share_license_v1},
        metadata       = #{timestamp => erlang:system_time(millisecond)}},
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => share_licenses_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual}).
