%%% @doc Synthesise an RFC 1035 RRset for the queried qtype from
%%% the verified records `resolve_mesh_names' returned.
%%% PLAN_DNS_OVER_MESH_PART1 §7.
%%%
%%%   synth(QName, QType, VerifiedRecords, Opts) ->
%%%       {answer, [rr()]}    %% NOERROR with these answer RRs
%%%     | nodata              %% NOERROR + empty answer (name exists,
%%%                           %%   no record of this qtype)
%%%     | notimp              %% NOTIMP (ANY per RFC 8482; TLSA until
%%%                           %%   macula 4.4.0 ships dane_pin)
%%%
%%% Per-qtype rules (the ones with a live data source in macula 4.x):
%%%   AAAA / A : station_endpoint.host_advertised, filtered by family
%%%   SRV      : station_endpoint → `0 0 <quic_port> <station-qname>'
%%%   TXT      : record version + ALPN as quoted strings
%%%   SOA      : realm_directory → MNAME = z32(realm-pk) ‖ `._st.macula.io.'
%%%   PTR / NS : not yet — PTR needs the reverse path wired,
%%%              NS needs the realm_stations record. Both return
%%%              `[]' → NODATA for now (a valid "exists, no such
%%%              record" answer, not a lie).
%%%   TLSA     : NOTIMP + EDE("tlsa_unsupported") — dane_pin is a
%%%              macula 4.4.0 candidate.
%%%   ANY      : NOTIMP per RFC 8482 §6.
%%%   other    : NODATA.
%%%
%%% RR TTL (PART1 §7.1): clamp((expires_at - now) // 1000,
%%% min_rr_ttl, max_rr_ttl). Defaults 60 / 3600, app env
%%% configurable. `rr_ttl/2' is exported for the per-qtype modules.
%%%
%%% Reading payload fields: a verified record's `payload' is the raw
%%% macula_record payload, and `macula_record:decode/1' (CBOR) is
%%% non-deterministic about key form — it `binary_to_existing_atom's
%%% text-string keys, so a decoded `station_endpoint' payload comes
%%% back with `host_advertised'/`alpn' as bare atoms but `quic_port'
%%% as `{text, <<"quic_port">>}', and a scalar text value stays
%%% wrapped (`{text, Bin}') while text values inside a list come back
%%% as bare binaries. The per-qtype modules read payload fields via
%%% `payload_field/4' (tries atom ⊕ `{text, bin}' ⊕ bare-bin keys,
%%% unwraps a `{text, V}' value) so they work on both freshly-built
%%% and CBOR-round-tripped records. `rr_ttl/2', `station_qname/1',
%%% `payload_field/4' are exported for the per-qtype modules.
%%% @end
-module(synthesize_rr_set).

-export([synth/4, rr_ttl/2, station_qname/1, payload_field/4]).

-define(DEFAULT_MIN_RR_TTL, 60).
-define(DEFAULT_MAX_RR_TTL, 3600).

-type rr() :: map().    %% the shape compose_response:encode_rr/1 expects

%%====================================================================
%% Public API
%%====================================================================

-spec synth(QName :: binary(),
            QType :: atom() | non_neg_integer(),
            VerifiedRecords :: [map()],
            Opts :: map()) ->
    {answer, [rr()]} | nodata | notimp.
synth(_QName, any,  _VRs, _Opts) -> notimp;          %% RFC 8482
synth(_QName, tlsa, _VRs, _Opts) -> notimp;          %% dane_pin pending (4.4.0)
synth(QName, QType, VRs, Opts) ->
    RRs = case QType of
              aaaa -> synth_aaaa:rrs(QName, VRs, Opts);
              a    -> synth_a:rrs(QName, VRs, Opts);
              srv  -> synth_srv:rrs(QName, VRs, Opts);
              txt  -> synth_txt:rrs(QName, VRs, Opts);
              soa  -> synth_soa:rrs(QName, VRs, Opts);
              ptr  -> synth_ptr:rrs(QName, VRs, Opts);
              ns   -> synth_ns:rrs(QName, VRs, Opts);
              _    -> []
          end,
    case RRs of
        [] -> nodata;
        _  -> {answer, RRs}
    end.

%% @doc TTL for an RR derived from a verified record: clamp the
%% record's remaining lifetime (seconds) to [min_rr_ttl, max_rr_ttl].
-spec rr_ttl(VerifiedRecord :: map(), Opts :: map()) -> non_neg_integer().
rr_ttl(VR, Opts) ->
    NowMs   = maps:get(now_ms, Opts, erlang:system_time(millisecond)),
    ExpAtMs = maps:get(expires_at, VR, 0),
    RemSec  = max(0, (ExpAtMs - NowMs) div 1000),
    Min = app_env(min_rr_ttl, ?DEFAULT_MIN_RR_TTL),
    Max = app_env(max_rr_ttl, ?DEFAULT_MAX_RR_TTL),
    clamp(RemSec, Min, Max).

%% @doc DNS qname for a station pubkey: `<z32(pubkey)>._st.macula.io.'.
%% Accepts a raw 32-byte pubkey or an already-z32-encoded binary.
%% Returns `undefined' if it can't be encoded.
-spec station_qname(Pubkey :: binary()) -> binary() | undefined.
station_qname(Pubkey) ->
    case qname_station:format_pubkey(Pubkey) of
        {ok, Z32} ->
            case qname_to_mri:format(<<"mri:station:", Z32/binary>>) of
                {ok, QName}    -> QName;
                {error, _}     -> undefined
            end;
        {error, _} ->
            undefined
    end.

%% @doc Read a payload field, tolerating macula's CBOR-decode key
%% forms: the field may be keyed by `{text, BinKey}', by the bare
%% atom `AtomKey' (macula's decode atom-converts text keys whose atom
%% pre-exists in loaded code), or by the bare binary `BinKey'. A
%% `{text, V}'-wrapped binary value is unwrapped; everything else
%% (lists, integers, bare binaries) is returned as-is. Returns
%% `Default' if no key form is present.
-spec payload_field(map(), atom(), binary(), term()) -> term().
payload_field(P, AtomKey, BinKey, Default) when is_map(P) ->
    Raw = case maps:find({text, BinKey}, P) of
              {ok, V0} -> V0;
              error ->
                  case maps:find(AtomKey, P) of
                      {ok, V1} -> V1;
                      error    -> maps:get(BinKey, P, Default)
                  end
          end,
    unwrap_text(Raw);
payload_field(_, _, _, Default) ->
    Default.

%% @doc Unwrap a `{text, Bin}'-wrapped binary; pass anything else
%% through unchanged. (macula's CBOR codec wraps scalar text values
%% but leaves text values inside lists bare — useful for normalising
%% individual list elements too.)
-spec unwrap_text(term()) -> term().
unwrap_text({text, B}) when is_binary(B) -> B;
unwrap_text(V) -> V.

%%====================================================================
%% Helpers
%%====================================================================

clamp(V, Min, _Max) when V < Min -> Min;
clamp(V, _Min, Max) when V > Max -> Max;
clamp(V, _Min, _Max) -> V.

app_env(Key, Default) ->
    application:get_env(serve_dns_over_mesh, Key, Default).
