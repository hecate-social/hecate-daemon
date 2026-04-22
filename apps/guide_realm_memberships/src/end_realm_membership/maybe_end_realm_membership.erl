%%% @doc Handler for end_realm_membership_v1.
%%%
%%% Validates membership_id is present, returns a single
%%% `realm_membership_ended_v1` event. The resign path returns two
%%% events (resigned + ended) via its own handler — this handler is
%%% used by the admin-revoke listener.
%%% @end
-module(maybe_end_realm_membership).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{membership_id := MId} = Payload) when is_binary(MId), byte_size(MId) > 0 ->
    Reason   = maps:get(reason,   Payload, revoked),
    EndedBy  = maps:get(ended_by, Payload, undefined),
    EndedAt  = maps:get(ended_at, Payload, erlang:system_time(millisecond)),
    {ok, Event} = realm_membership_ended_v1:new(#{
        membership_id => MId,
        reason        => Reason,
        ended_by      => EndedBy,
        ended_at      => EndedAt}),
    {ok, [realm_membership_ended_v1:to_map(Event)]};
handle_from_map(_) ->
    {error, membership_id_required}.

-spec handle(end_realm_membership_v1:end_realm_membership_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Cmd) ->
    handle_from_map(end_realm_membership_v1:to_map(Cmd)).

-spec dispatch(end_realm_membership_v1:end_realm_membership_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    Payload = end_realm_membership_v1:to_map(Cmd),
    MId = maps:get(membership_id, Payload),
    StreamId = membership_aggregate:stream_id(MId),
    EvoqCmd = #evoq_command{
        command_type   = end_realm_membership_v1,
        aggregate_type = membership_aggregate,
        aggregate_id   = StreamId,
        payload        = Payload#{command_type => end_realm_membership_v1},
        metadata       = #{timestamp => erlang:system_time(millisecond)}},
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => realm_memberships_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual}).
