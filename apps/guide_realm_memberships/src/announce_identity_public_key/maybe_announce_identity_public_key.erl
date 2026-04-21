%%% @doc Handler for announce_identity_public_key_v1.
-module(maybe_announce_identity_public_key).

-export([handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{membership_id := _, mri := _,
                  encryption_public_key := Pub} = Payload)
  when is_binary(Pub), byte_size(Pub) == 32 ->
    At = maps:get(announced_at, Payload, erlang:system_time(millisecond)),
    {ok, Event} = identity_public_key_announced_v1:new(Payload#{announced_at => At}),
    {ok, [identity_public_key_announced_v1:to_map(Event)]};
handle_from_map(_) ->
    {error, missing_fields}.

-spec dispatch(announce_identity_public_key_v1:announce_identity_public_key_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{membership_id := MembershipId} = Payload =
        announce_identity_public_key_v1:to_map(Cmd),
    StreamId = membership_aggregate:stream_id(MembershipId),
    EvoqCmd = #evoq_command{
        command_type   = announce_identity_public_key,
        aggregate_type = membership_aggregate,
        aggregate_id   = StreamId,
        payload        = Payload#{command_type => announce_identity_public_key},
        metadata       = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => realm_memberships_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual
    }).
