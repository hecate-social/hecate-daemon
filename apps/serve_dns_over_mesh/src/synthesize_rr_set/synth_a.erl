%%% @doc QTYPE A synthesiser. PLAN_DNS_OVER_MESH_PART1 §7:
%%% `station_endpoint.host_advertised', filtered to IPv4 addresses.
%%% One A RR per advertised v4 host. (Macula stations are normally
%%% v6-only via macula-net, so this is usually empty → NODATA;
%%% present for completeness + dual-stack stations.)
%%% @end
-module(synth_a).

-export([rrs/3]).

-spec rrs(QName :: binary(), VRs :: [map()], Opts :: map()) -> [map()].
rrs(QName, VRs, Opts) ->
    lists:flatmap(
      fun(#{record_type := station_endpoint} = VR) ->
              Ttl   = synthesize_rr_set:rr_ttl(VR, Opts),
              Hosts = host_advertised(VR),
              [#{name => QName, type => a, ttl => Ttl, rdata => Addr}
               || H <- Hosts, {ok, Addr} <- [parse_v4(H)]];
         (_) ->
              []
      end, VRs).

host_advertised(#{payload := P}) when is_map(P) ->
    case synthesize_rr_set:payload_field(P, host_advertised, <<"host_advertised">>, []) of
        L when is_list(L) -> L;
        _                 -> []
    end;
host_advertised(_) ->
    [].

%% Host strings may arrive bare or, defensively, `{text, Bin}'-wrapped.
parse_v4({text, B}) when is_binary(B) -> parse_v4(B);
parse_v4(Host) when is_binary(Host) ->
    case inet:parse_address(binary_to_list(Host)) of
        {ok, {_, _, _, _} = V4} -> {ok, V4};
        _                       -> {error, not_v4}
    end;
parse_v4(_) ->
    {error, not_v4}.
