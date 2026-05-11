%%% @doc QTYPE NS synthesiser. PLAN_DNS_OVER_MESH_PART1 §7:
%%% realm-apex NS → each realm station's `_st.macula.io.' name,
%%% sourced from the `realm_stations' record (type 0x04).
%%%
%%% Returns `[]' for now (→ NODATA): we don't fetch the
%%% `realm_stations' record yet (resolve_mri doesn't resolve
%%% realm-apex MRIs, and realm_stations isn't a leaf type the
%%% trust chain walks). Activates once a realm_stations verified-
%%% record reaches here — it then emits one NS RR per listed
%%% station pubkey via synthesize_rr_set:station_qname/1.
%%% @end
-module(synth_ns).

-export([rrs/3]).

-spec rrs(QName :: binary(), VRs :: [map()], Opts :: map()) -> [map()].
rrs(QName, VRs, Opts) ->
    lists:flatmap(
      fun(#{record_type := realm_stations} = VR) ->
              Ttl   = synthesize_rr_set:rr_ttl(VR, Opts),
              Pks   = station_pubkeys(VR),
              [#{name => QName, type => ns, ttl => Ttl, rdata => Target}
               || Pk <- Pks,
                  Target <- [synthesize_rr_set:station_qname(Pk)],
                  is_binary(Target)];
         (_) ->
              []
      end, VRs).

%% realm_stations payload carries a list of station entries; each
%% has a pubkey field. Tolerate both a flat pubkey list and a
%% list of maps with a `{text, <<"pubkey">>}' key.
station_pubkeys(#{payload := P}) when is_map(P) ->
    case maps:get({text, <<"stations">>}, P, []) of
        L when is_list(L) ->
            lists:filtermap(fun
                (Pk) when is_binary(Pk), byte_size(Pk) =:= 32 -> {true, Pk};
                (#{} = E) ->
                    case maps:get({text, <<"pubkey">>}, E, undefined) of
                        Pk when is_binary(Pk), byte_size(Pk) =:= 32 -> {true, Pk};
                        _ -> false
                    end;
                (_) -> false
            end, L);
        _ ->
            []
    end;
station_pubkeys(_) ->
    [].
