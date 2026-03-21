%%% @doc Mesh proof probe: pub/sub round-trip.
%%%
%%% Subscribes to a unique topic, publishes a nonce, and verifies
%%% the message arrives back. Proves the pub/sub pipeline works.
%%% @end
-module(probe_mesh_pubsub).

-export([run/1]).

-define(TIMEOUT_MS, 3000).

-spec run(pid()) -> {ok, map()} | {error, term()}.
run(Client) ->
    Nonce = crypto:strong_rand_bytes(16),
    NonceHex = binary:encode_hex(Nonce),
    {ok, NodeId} = macula:get_node_id(Client),
    NodeIdHex = binary:encode_hex(NodeId),
    Topic = <<"hecate.proof.pubsub.", NodeIdHex/binary>>,
    Self = self(),
    Ref = make_ref(),

    Callback = fun(EventData) ->
        case EventData of
            #{<<"nonce">> := N} when N =:= NonceHex ->
                Self ! {probe_pubsub_received, Ref};
            _ ->
                ok
        end,
        ok
    end,

    Start = erlang:monotonic_time(millisecond),
    case macula:subscribe(Client, Topic, Callback) of
        {ok, SubRef} ->
            timer:sleep(100),
            Payload = #{nonce => NonceHex, timestamp => erlang:system_time(millisecond)},
            case macula:publish(Client, Topic, Payload) of
                ok ->
                    Result = receive
                        {probe_pubsub_received, Ref} ->
                            Elapsed = erlang:monotonic_time(millisecond) - Start,
                            {ok, #{round_trip_ms => Elapsed}}
                    after ?TIMEOUT_MS ->
                        {error, timeout}
                    end,
                    macula:unsubscribe(Client, SubRef),
                    Result;
                {error, Reason} ->
                    macula:unsubscribe(Client, SubRef),
                    {error, {publish_failed, Reason}}
            end;
        {error, Reason} ->
            {error, {subscribe_failed, Reason}}
    end.
