%%% @doc QTYPE PTR synthesiser. PLAN_DNS_OVER_MESH_PART1 §7,
%%% §3.4.9: reverse-IPv6 → `address_pubkey_map' → PTR pointing at
%%% `<z32(pubkey)>._st.macula.io.'.
%%%
%%% Returns `[]' for now (→ NODATA): the reverse path
%%% (`qname_reverse_v6') isn't wired into the lookup pipeline yet —
%%% it returns `{error, reverse_v6_lookup_required}'. Once the
%%% pipeline routes reverse-arpa queries through resolve_mesh_names
%%% and an `address_pubkey_map' verified-record reaches here, this
%%% reads `payload.station_pubkey' and emits the PTR.
%%% @end
-module(synth_ptr).

-export([rrs/3]).

-spec rrs(QName :: binary(), VRs :: [map()], Opts :: map()) -> [map()].
rrs(QName, VRs, Opts) ->
    lists:filtermap(
      fun(#{record_type := address_pubkey_map} = VR) ->
              case station_pubkey(VR) of
                  Pk when is_binary(Pk) ->
                      case synthesize_rr_set:station_qname(Pk) of
                          undefined -> false;
                          Target ->
                              Ttl = synthesize_rr_set:rr_ttl(VR, Opts),
                              {true, #{name => QName, type => ptr, ttl => Ttl,
                                       rdata => Target}}
                      end;
                  _ ->
                      false
              end;
         (_) ->
              false
      end, VRs).

%% address_pubkey_map's payload maps an address to a station
%% pubkey; the field name in macula 4.x is `station_pubkey'
%% (under the `{text, _}'-tuple key convention).
station_pubkey(#{payload := P}) when is_map(P) ->
    maps:get({text, <<"station_pubkey">>}, P, undefined);
station_pubkey(_) ->
    undefined.
