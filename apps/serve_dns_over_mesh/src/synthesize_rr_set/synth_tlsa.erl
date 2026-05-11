%%% @doc QTYPE TLSA synthesiser. PLAN_DNS_OVER_MESH_PART1 §7 +
%%% §11: `3 1 1 <SHA-256(SPKI)>' (DANE-EE, selector=SPKI,
%%% match=SHA-256) sourced from a `dane_pin' record.
%%%
%%% `dane_pin' (record type 0x15) is a macula 4.4.0 candidate —
%%% not in 4.x. Until it ships, TLSA queries are answered
%%% NOTIMP + EDE("tlsa_unsupported") by the dispatcher
%%% (`synthesize_rr_set:synth/4' short-circuits `tlsa' to `notimp'
%%% before reaching here). This module exists so the slice
%%% compiles; `rrs/3' returns `[]' should it ever be called.
%%% @end
-module(synth_tlsa).

-export([rrs/3]).

-spec rrs(QName :: binary(), VRs :: [map()], Opts :: map()) -> [map()].
rrs(_QName, _VRs, _Opts) ->
    [].
