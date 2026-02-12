-module(maybe_revoke_ucan).
-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).
-include_lib("evoq/include/evoq.hrl").

handle(Command) ->
    #{capability_id := CapId, revoker := Revoker, revoked_at := At} = revoke_ucan_v1:to_map(Command),
    case {byte_size(CapId), byte_size(Revoker)} of
        {0, _} -> {error, capability_id_required};
        {_, 0} -> {error, revoker_required};
        _ ->
            Event = ucan_revoked_v1:new(CapId, Revoker, At),
            {ok, [ucan_revoked_v1:to_map(Event)]}
    end.

handle_from_map(Payload) ->
    CapId = maps:get(capability_id, Payload, maps:get(<<"capability_id">>, Payload, <<>>)),
    Revoker = maps:get(revoker, Payload, maps:get(<<"revoker">>, Payload, <<>>)),
    At = maps:get(revoked_at, Payload, maps:get(<<"revoked_at">>, Payload, erlang:system_time(millisecond))),
    Cmd = revoke_ucan_v1:new(CapId, Revoker, At),
    handle(Cmd).

dispatch(Cmd) ->
    #{capability_id := CapId} = revoke_ucan_v1:to_map(Cmd),
    Timestamp = erlang:system_time(millisecond),
    CmdMap = revoke_ucan_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = revoke_ucan,
        aggregate_type = node_aggregate,
        aggregate_id = CapId,
        payload = CmdMap#{command_type => revoke_ucan},
        metadata = #{timestamp => Timestamp}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => hecate_event_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
