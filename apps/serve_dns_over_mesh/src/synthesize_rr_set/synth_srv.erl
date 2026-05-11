%%% @doc QTYPE SRV synthesiser. PLAN_DNS_OVER_MESH_PART1 §7.
%%%
%%% For a station_endpoint: `0 0 <quic_port> <station-qname>' —
%%% priority 0, weight 0, the advertised QUIC port, target =
%%% `<z32(station-pubkey)>._st.macula.io.'.
%%%
%%% (procedure_advertisement → SRV for the serving station is a
%%% follow-up — needs the serving-station pubkey from the proc
%%% record's payload + a separate station_endpoint lookup.)
%%% @end
-module(synth_srv).

-export([rrs/3]).

-spec rrs(QName :: binary(), VRs :: [map()], Opts :: map()) -> [map()].
rrs(QName, VRs, Opts) ->
    lists:filtermap(
      fun(#{record_type := station_endpoint, signer_pubkey := Pk} = VR) ->
              Ttl  = synthesize_rr_set:rr_ttl(VR, Opts),
              Port = quic_port(VR),
              Target = synthesize_rr_set:station_qname(Pk),
              case {Port, Target} of
                  {P, T} when is_integer(P), P > 0, P =< 65535, is_binary(T) ->
                      {true, #{name => QName, type => srv, ttl => Ttl,
                               rdata => {0, 0, P, T}}};
                  _ ->
                      false
              end;
         (_) ->
              false
      end, VRs).

quic_port(#{payload := P}) when is_map(P) ->
    maps:get({text, <<"quic_port">>}, P, undefined);
quic_port(_) ->
    undefined.
