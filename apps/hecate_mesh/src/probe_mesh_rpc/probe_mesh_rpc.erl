%%% @doc Mesh proof probe: RPC advertise + call round-trip.
%%%
%%% Advertises a procedure, calls it, and verifies the nonce echoes
%%% back. Proves the advertise-call pipeline works.
%%%
%%% Note: macula RPC has a local shortcut - if the procedure is
%%% registered locally, the call executes in-process (zero-network).
%%% This still proves the advertise/call pipeline works.
%%% @end
-module(probe_mesh_rpc).

-export([run/1]).

-define(TIMEOUT_MS, 3000).

-spec run(pid()) -> {ok, map()} | {error, term()}.
run(Client) ->
    Nonce = crypto:strong_rand_bytes(16),
    NonceHex = binary:encode_hex(Nonce),
    {ok, NodeId} = macula:get_node_id(Client),
    NodeIdHex = binary:encode_hex(NodeId),
    Procedure = <<"hecate.proof.rpc.", NodeIdHex/binary>>,

    Handler = fun(Args) ->
        RecvNonce = maps:get(<<"nonce">>, Args, maps:get(nonce, Args, undefined)),
        {ok, #{echo => RecvNonce}}
    end,

    Start = erlang:monotonic_time(millisecond),
    case macula:advertise(Client, Procedure, Handler) of
        {ok, AdvRef} ->
            timer:sleep(100),
            CallResult = try
                macula:call(Client, Procedure, #{nonce => NonceHex})
            catch
                Class:Ex ->
                    {error, {call_exception, Class, Ex}}
            end,
            macula:unadvertise(Client, AdvRef),
            case CallResult of
                {ok, #{echo := EchoNonce}} when EchoNonce =:= NonceHex ->
                    Elapsed = erlang:monotonic_time(millisecond) - Start,
                    {ok, #{round_trip_ms => Elapsed}};
                {ok, #{<<"echo">> := EchoNonce}} when EchoNonce =:= NonceHex ->
                    Elapsed = erlang:monotonic_time(millisecond) - Start,
                    {ok, #{round_trip_ms => Elapsed}};
                {ok, Other} ->
                    {error, {nonce_mismatch, Other}};
                {error, CallErr} ->
                    {error, {call_failed, CallErr}}
            end;
        {error, AdvErr} ->
            {error, {advertise_failed, AdvErr}}
    end.
