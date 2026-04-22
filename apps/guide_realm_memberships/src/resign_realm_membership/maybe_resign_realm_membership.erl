%%% @doc Handler for resign_realm_membership_v1.
%%%
%%% Returns BOTH events in a single evoq `execute/2`:
%%%   1. `realm_membership_resigned_v1` — mesh-published fact so the
%%%       realm server rotates K_realm (debounced).
%%%   2. `realm_membership_ended_v1 {reason: :resigned}` — terminal
%%%       local state transition.
%%%
%%% The aggregate threads state fields (realm_id, member_did) into the
%%% payload via `enrich_from_state/2` before this handler runs.
%%% @end
-module(maybe_resign_realm_membership).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{membership_id := MId} = Payload) when is_binary(MId), byte_size(MId) > 0 ->
    At = maps:get(resigned_at, Payload, erlang:system_time(millisecond)),
    {ok, Resigned} = realm_membership_resigned_v1:new(#{
        membership_id => MId,
        realm_id      => maps:get(realm_id,   Payload, undefined),
        member_did    => maps:get(member_did, Payload, undefined),
        resigned_at   => At}),
    {ok, Ended} = realm_membership_ended_v1:new(#{
        membership_id => MId,
        reason        => resigned,
        ended_by      => maps:get(member_did, Payload, undefined),
        ended_at      => At}),
    {ok, [realm_membership_resigned_v1:to_map(Resigned),
          realm_membership_ended_v1:to_map(Ended)]};
handle_from_map(_) ->
    {error, membership_id_required}.

-spec handle(resign_realm_membership_v1:resign_realm_membership_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Cmd) ->
    handle_from_map(resign_realm_membership_v1:to_map(Cmd)).

-spec dispatch(resign_realm_membership_v1:resign_realm_membership_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    Payload = resign_realm_membership_v1:to_map(Cmd),
    MId = maps:get(membership_id, Payload),
    StreamId = membership_aggregate:stream_id(MId),
    EvoqCmd = #evoq_command{
        command_type   = resign_realm_membership_v1,
        aggregate_type = membership_aggregate,
        aggregate_id   = StreamId,
        payload        = Payload#{command_type => resign_realm_membership_v1},
        metadata       = #{timestamp => erlang:system_time(millisecond)}},
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => realm_memberships_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual}).
