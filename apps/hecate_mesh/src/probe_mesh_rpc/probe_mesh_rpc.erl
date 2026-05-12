%%% @doc Mesh proof probe: RPC advertise + call round-trip.
%%%
%%% Advertises a procedure on the realm, calls it, and verifies the
%%% nonce echoes back. Proves the V2 pool advertise/call pipeline
%%% works end to end.
%%% @end
-module(probe_mesh_rpc).

-export([run/1]).

-define(TIMEOUT_MS, 3000).

-spec run(macula:pool()) -> {ok, map()} | {error, term()}.
run(Pool) ->
    RealmId = realm_id(),
    Nonce = crypto:strong_rand_bytes(16),
    NonceHex = binary:encode_hex(Nonce),
    {ok, #{self_node_id := NodeId}} = macula:status(Pool),
    Procedure = <<"hecate.proof.rpc.", (binary:encode_hex(NodeId))/binary>>,

    Handler = fun(Args) ->
        RecvNonce = maps:get(<<"nonce">>, Args, maps:get(nonce, Args, undefined)),
        {ok, #{echo => RecvNonce}}
    end,

    Start = erlang:monotonic_time(millisecond),
    case macula:advertise(Pool, RealmId, Procedure, Handler, #{}) of
        ok ->
            timer:sleep(100),
            CallResult = try
                macula:call(Pool, RealmId, Procedure, #{nonce => NonceHex}, ?TIMEOUT_MS)
            catch
                Class:Ex ->
                    {error, {call_exception, Class, Ex}}
            end,
            macula:unadvertise(Pool, RealmId, Procedure),
            case CallResult of
                {ok, #{echo := EchoNonce}} when EchoNonce =:= NonceHex ->
                    {ok, #{round_trip_ms => erlang:monotonic_time(millisecond) - Start}};
                {ok, #{<<"echo">> := EchoNonce}} when EchoNonce =:= NonceHex ->
                    {ok, #{round_trip_ms => erlang:monotonic_time(millisecond) - Start}};
                {ok, Other} ->
                    {error, {nonce_mismatch, Other}};
                {error, CallErr} ->
                    {error, {call_failed, CallErr}}
            end;
        {error, AdvErr} ->
            {error, {advertise_failed, AdvErr}}
    end.

realm_id() ->
    macula_realm:id(application:get_env(hecate, realm, <<"io.macula">>)).
