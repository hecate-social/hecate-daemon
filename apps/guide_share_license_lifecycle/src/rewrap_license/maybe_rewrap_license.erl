%%% @doc Handler for rewrap_license_v1.
%%%
%%% Enriches the event with grantee/realm/issuer_did pulled off the
%%% aggregate state (via `enrich_from_state/2` in the aggregate) so the
%%% batched mesh FACT carries enough for recipient filtering without a
%%% second store lookup. Aggregate guards enforce monotonic version
%%% advancement.
%%% @end
-module(maybe_rewrap_license).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{license_id          := _,
                  new_wrapped_cek     := _,
                  new_k_realm_version := _,
                  batch_id            := _} = Payload) ->
    RewrappedAt = maps:get(rewrapped_at, Payload, erlang:system_time(millisecond)),
    {ok, Event} = license_rewrapped_v1:new(Payload#{rewrapped_at => RewrappedAt}),
    {ok, [license_rewrapped_v1:to_map(Event)]};
handle_from_map(_) ->
    {error, missing_fields}.

-spec handle(rewrap_license_v1:rewrap_license_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Cmd) ->
    handle_from_map(rewrap_license_v1:to_map(Cmd)).

-spec dispatch(rewrap_license_v1:rewrap_license_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    Payload = rewrap_license_v1:to_map(Cmd),
    LicenseId = maps:get(license_id, Payload),
    StreamId = issued_license_aggregate:stream_id(LicenseId),
    EvoqCmd = #evoq_command{
        command_type   = rewrap_license_v1,
        aggregate_type = issued_license_aggregate,
        aggregate_id   = StreamId,
        payload        = Payload#{command_type => rewrap_license_v1},
        metadata       = #{timestamp => erlang:system_time(millisecond)}},
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => share_licenses_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual}).
