%%% @doc Handler for store_realm_shared_key_v1.
%%%
%%% The aggregate is responsible for state-level checks (confirmed but
%%% not revoked). This handler translates the payload into the fat
%%% realm_shared_key_stored_v1 event.
%%% @end
-module(maybe_store_realm_shared_key).

-export([handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{membership_id := _,
                  realm := _,
                  k_realm_version := V,
                  k_realm_encrypted := Enc} = Payload)
  when is_integer(V), V > 0, is_binary(Enc), byte_size(Enc) > 0 ->
    ReceivedAt = maps:get(received_at, Payload, erlang:system_time(millisecond)),
    {ok, Event} = realm_shared_key_stored_v1:new(Payload#{received_at => ReceivedAt}),
    {ok, [realm_shared_key_stored_v1:to_map(Event)]};
handle_from_map(_) ->
    {error, missing_fields}.

-spec dispatch(store_realm_shared_key_v1:store_realm_shared_key_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{membership_id := MembershipId} = Payload =
        store_realm_shared_key_v1:to_map(Cmd),
    StreamId = membership_aggregate:stream_id(MembershipId),
    EvoqCmd = #evoq_command{
        command_type   = store_realm_shared_key,
        aggregate_type = membership_aggregate,
        aggregate_id   = StreamId,
        payload        = Payload#{command_type => store_realm_shared_key},
        metadata       = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => realm_memberships_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual
    }).
