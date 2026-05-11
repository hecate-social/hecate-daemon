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
    maps:get({text, <<"host_advertised">>}, P, []);
host_advertised(_) ->
    [].

parse_v6(Host) when is_binary(Host) ->
    case inet:parse_address(binary_to_list(Host)) of
        {ok, {_, _, _, _, _, _, _, _} = V6} -> {ok, V6};
        _                                   -> {error, not_v6}
    end;
parse_v6(_) ->
    {error, not_v6}.
