%%% @doc Mesh proof probe: pub/sub round-trip.
%%%
%%% Subscribes to a unique topic on the realm, publishes a nonce, and
%%% verifies the message arrives back. Proves the V2 pool pub/sub
%%% pipeline works end to end.
%%% @end
-module(probe_mesh_pubsub).

-export([run/1]).

-define(TIMEOUT_MS, 3000).

-spec run(macula:pool()) -> {ok, map()} | {error, term()}.
run(Pool) ->
    RealmId = realm_id(),
    Nonce = crypto:strong_rand_bytes(16),
    NonceHex = binary:encode_hex(Nonce),
    {ok, #{self_node_id := NodeId}} = macula:status(Pool),
    Topic = <<"hecate.proof.pubsub.", (binary:encode_hex(NodeId))/binary>>,
    Self = self(),
    Ref = make_ref(),

    Callback = fun(_Topic, EventData, _Meta) ->
        case EventData of
            #{<<"nonce">> := N} when N =:= NonceHex ->
                Self ! {probe_pubsub_received, Ref};
            #{nonce := N} when N =:= NonceHex ->
                Self ! {probe_pubsub_received, Ref};
            _ ->
                ok
        end,
        ok
    end,

    Start = erlang:monotonic_time(millisecond),
    case macula:subscribe_callback(Pool, RealmId, Topic, Callback) of
        {ok, SubRef} ->
            timer:sleep(100),
            Payload = #{nonce => NonceHex, timestamp => erlang:system_time(millisecond)},
            case macula:publish(Pool, RealmId, Topic, Payload) of
                ok ->
                    Result = receive
                        {probe_pubsub_received, Ref} ->
                            Elapsed = erlang:monotonic_time(millisecond) - Start,
                            {ok, #{round_trip_ms => Elapsed}}
                    after ?TIMEOUT_MS ->
                        {error, timeout}
                    end,
                    macula:unsubscribe(Pool, SubRef),
                    Result;
                {error, Reason} ->
                    macula:unsubscribe(Pool, SubRef),
                    {error, {publish_failed, Reason}}
            end;
        {error, Reason} ->
            {error, {subscribe_failed, Reason}}
    end.

realm_id() ->
    macula_realm:id(application:get_env(hecate, realm, <<"io.macula">>)).
