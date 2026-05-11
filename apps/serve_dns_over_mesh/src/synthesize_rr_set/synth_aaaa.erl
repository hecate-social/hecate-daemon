%%% @doc QTYPE AAAA synthesiser. PLAN_DNS_OVER_MESH_PART1 §7:
%%% `station_endpoint.host_advertised', filtered to IPv6 addresses.
%%% One AAAA RR per advertised v6 host.
%%% @end
-module(synth_aaaa).

-export([rrs/3]).

-spec rrs(QName :: binary(), VRs :: [map()], Opts :: map()) -> [map()].
rrs(QName, VRs, Opts) ->
    lists:flatmap(
      fun(#{record_type := station_endpoint} = VR) ->
              Ttl   = synthesize_rr_set:rr_ttl(VR, Opts),
              Hosts = host_advertised(VR),
              [#{name => QName, type => aaaa, ttl => Ttl, rdata => Addr}
               || H <- Hosts, {ok, Addr} <- [parse_v6(H)]];
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
parse_v6({text, B}) when is_binary(B) -> parse_v6(B);
parse_v6(Host) when is_binary(Host) ->
    case inet:parse_address(binary_to_list(Host)) of
        {ok, {_, _, _, _, _, _, _, _} = V6} -> {ok, V6};
        _                                   -> {error, not_v6}
    end;
parse_v6(_) ->
    {error, not_v6}.
