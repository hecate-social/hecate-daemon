%%% @doc QTYPE TXT synthesiser. PLAN_DNS_OVER_MESH_PART1 §7:
%%% record metadata as quoted strings. For a station_endpoint we
%%% emit one TXT RR carrying `alpn=<value>' when the record
%%% advertises an ALPN; nothing otherwise (→ NODATA).
%%% @end
-module(synth_txt).

-export([rrs/3]).

-spec rrs(QName :: binary(), VRs :: [map()], Opts :: map()) -> [map()].
rrs(QName, VRs, Opts) ->
    lists:filtermap(
      fun(VR) ->
              case txt_strings(VR) of
                  []      -> false;
                  Strings ->
                      Ttl = synthesize_rr_set:rr_ttl(VR, Opts),
                      {true, #{name => QName, type => txt, ttl => Ttl,
                               rdata => Strings}}
              end
      end, VRs).

txt_strings(#{payload := P}) when is_map(P) ->
    case synthesize_rr_set:payload_field(P, alpn, <<"alpn">>, undefined) of
        A when is_binary(A) -> [<<"alpn=", A/binary>>];
        _                   -> []
    end;
txt_strings(_) ->
    [].
