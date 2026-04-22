%%% @doc Handler for end_license_v1.
-module(maybe_end_license).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{license_id := _, reason := _} = Payload) ->
    EndedAt = maps:get(ended_at, Payload, erlang:system_time(millisecond)),
    {ok, Event} = license_ended_v1:new(Payload#{ended_at => EndedAt}),
    {ok, [license_ended_v1:to_map(Event)]};
handle_from_map(_) ->
    {error, missing_fields}.

-spec handle(end_license_v1:end_license_v1()) -> {ok, [map()]} | {error, term()}.
handle(Cmd) ->
    handle_from_map(end_license_v1:to_map(Cmd)).

-spec dispatch(end_license_v1:end_license_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    Payload = end_license_v1:to_map(Cmd),
    LicenseId = maps:get(license_id, Payload),
    StreamId = accepted_license_aggregate:stream_id(LicenseId),
    EvoqCmd = #evoq_command{
        command_type   = end_license_v1,
        aggregate_type = accepted_license_aggregate,
        aggregate_id   = StreamId,
        payload        = Payload#{command_type => end_license_v1},
        metadata       = #{timestamp => erlang:system_time(millisecond)}},
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => share_licenses_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual}).
