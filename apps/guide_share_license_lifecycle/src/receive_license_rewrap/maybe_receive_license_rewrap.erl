%%% @doc Handler for receive_license_rewrap_v1.
%%%
%%% Pure metadata update on the recipient aggregate. The aggregate
%%% guards enforce monotonic version advancement (same guard as issuer
%%% side), so replayed / stale rewraps from the mesh or catch-up worker
%%% are rejected cleanly without disturbing the stored bytes.
%%% @end
-module(maybe_receive_license_rewrap).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{license_id          := _,
                  new_wrapped_cek     := _,
                  new_k_realm_version := _} = Payload) ->
    ReceivedAt = maps:get(received_at, Payload, erlang:system_time(millisecond)),
    {ok, Event} = license_rewrap_received_v1:new(Payload#{received_at => ReceivedAt}),
    {ok, [license_rewrap_received_v1:to_map(Event)]};
handle_from_map(_) ->
    {error, missing_fields}.

-spec handle(receive_license_rewrap_v1:receive_license_rewrap_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Cmd) ->
    handle_from_map(receive_license_rewrap_v1:to_map(Cmd)).

-spec dispatch(receive_license_rewrap_v1:receive_license_rewrap_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    Payload = receive_license_rewrap_v1:to_map(Cmd),
    LicenseId = maps:get(license_id, Payload),
    StreamId = accepted_license_aggregate:stream_id(LicenseId),
    EvoqCmd = #evoq_command{
        command_type   = receive_license_rewrap_v1,
        aggregate_type = accepted_license_aggregate,
        aggregate_id   = StreamId,
        payload        = Payload#{command_type => receive_license_rewrap_v1},
        metadata       = #{timestamp => erlang:system_time(millisecond)}},
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => share_licenses_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual}).
