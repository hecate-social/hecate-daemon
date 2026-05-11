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
%%% @end
-module(synthesize_rr_set).

-export([synth/4, rr_ttl/2, station_qname/1]).

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

%%====================================================================
%% Helpers
%%====================================================================

clamp(V, Min, _Max) when V < Min -> Min;
clamp(V, _Min, Max) when V > Max -> Max;
clamp(V, _Min, _Max) -> V.

app_env(Key, Default) ->
    application:get_env(serve_dns_over_mesh, Key, Default).
