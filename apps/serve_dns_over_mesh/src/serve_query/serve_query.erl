%%% @doc serve_query: the DNS-bridge lookup pipeline. Each listener
%%% (UDP/TCP/DoH) hands a raw query packet here and gets back the
%%% raw response bytes — all the protocol-shape logic lives in
%%% one place. PLAN_DNS_OVER_MESH_PART1 §5.
%%%
%%% Flow:
%%%   1. parse_query:parse/1 — decode the packet
%%%   2. AXFR / IXFR  → REFUSED + EDE("zone_transfer_disabled")
%%%   3. classify_qname/1 — not_mesh → REFUSED (we never resolve
%%%      names outside our synthetic suffix)
%%%   4. no mesh connection (Pool = undefined) → SERVFAIL + EDE("dht_timeout")
%%%   5. qname_to_mri:resolve/1 — malformed → REFUSED + the typed cause
%%%   6. resolve_mesh_names_api:resolve/3 — map the result:
%%%        {ok, VRs}                 → synthesise + NOERROR
%%%        {error, name_revoked}     → NXDOMAIN + EDE("name_revoked")
%%%        {error, endorsement_expired} → NXDOMAIN + EDE
%%%        {error, name_not_endorsed}→ NXDOMAIN + EDE
%%%        {error, no_trust_root}    → REFUSED + EDE
%%%        {error, realm_not_trusted}→ REFUSED + EDE
%%%        {error, {not_resolvable_yet, _}} → SERVFAIL + EDE
%%%        {error, _}                → SERVFAIL + EDE (the cause atom)
%%%   7. synthesize_rr_set:synth/4 — {answer, RRs} → NOERROR+answers;
%%%      nodata → NOERROR+empty (name exists, no record of this
%%%      qtype); notimp → NOTIMP (+ EDE("tlsa_unsupported") for TLSA,
%%%      bare NOTIMP for ANY per RFC 8482)
%%%   8. compose_response:compose/1 — encode the reply (handles
%%%      EDNS0 OPT + TC=1 truncation)
%%%
%%% On a parse error: if the packet is at least a 12-byte header
%%% we send FORMERR (echoing the id); otherwise `drop' (the
%%% caller doesn't reply — the packet is too garbled to answer
%%% meaningfully).
%%% @end
-module(serve_query).

-export([handle/2, handle/3]).

%%====================================================================
%% Public API
%%====================================================================

%% @equiv handle(Pool, QueryBin, #{})
-spec handle(Pool :: pid() | undefined, QueryBin :: binary()) ->
    {ok, binary()} | drop.
handle(Pool, QueryBin) ->
    handle(Pool, QueryBin, #{}).

%% @doc Serve one DNS query. `Pool' is the macula client pool (or
%% `undefined' when the mesh isn't connected). `Opts' is forwarded
%% to resolve_mesh_names + synthesise (find_fn for tests, now_ms,
%% max_attempts).
-spec handle(Pool :: pid() | undefined, QueryBin :: binary(), Opts :: map()) ->
    {ok, binary()} | drop.
handle(Pool, QueryBin, Opts) ->
    case parse_query:parse(QueryBin) of
        {ok, Q} ->
            Spec = serve(Pool, Q, Opts),
            case compose_response:compose(Spec) of
                {ok, Bin}  -> {ok, Bin};
                {error, _} -> drop
            end;
        {error, no_question} ->
            formerr_response(QueryBin);
        {error, _} ->
            drop
    end.

%%====================================================================
%% Pipeline
%%====================================================================

serve(Pool, Q, Opts) ->
    QType = maps:get(qtype, Q),
    QName = maps:get(qname, Q),
    case QType of
        axfr -> error_spec(Q, refused, zone_transfer_disabled);
        ixfr -> error_spec(Q, refused, zone_transfer_disabled);
        _ ->
            case classify_qname:classify(QName) of
                not_mesh -> error_spec(Q, refused, not_in_mesh_suffix);
                mesh     -> serve_mesh(Pool, Q, Opts)
            end
    end.

serve_mesh(undefined, Q, _Opts) ->
    %% Daemon isn't connected to the mesh — can't resolve anything.
    error_spec(Q, servfail, dht_timeout);
serve_mesh(Pool, Q, Opts) ->
    QName = maps:get(qname, Q),
    QType = maps:get(qtype, Q),
    case qname_to_mri:resolve(QName) of
        {error, Reason} ->
            %% malformed_qname / name_too_long / not_in_mesh_suffix
            error_spec(Q, refused, Reason);
        {ok, Mri} ->
            case resolve_mesh_names_api:resolve(Pool, Mri, Opts) of
                {ok, VRs} when is_list(VRs) ->
                    synthesise_spec(Q, QName, QType, VRs, Opts);
                {error, name_revoked}        -> error_spec(Q, nxdomain, name_revoked);
                {error, endorsement_expired} -> error_spec(Q, nxdomain, endorsement_expired);
                {error, name_not_endorsed}   -> error_spec(Q, nxdomain, name_not_endorsed);
                {error, no_trust_root}       -> error_spec(Q, refused,  no_trust_root);
                {error, realm_not_trusted}   -> error_spec(Q, refused,  realm_not_trusted);
                {error, Reason}              -> error_spec(Q, servfail, Reason)
            end
    end.

synthesise_spec(Q, QName, QType, VRs, Opts) ->
    case synthesize_rr_set:synth(QName, QType, VRs, Opts) of
        {answer, RRs} ->
            ok_spec(Q, RRs);
        nodata ->
            %% Name exists, no record of this qtype: NOERROR + empty answer.
            ok_spec(Q, []);
        notimp ->
            EdeCause = case QType of
                           tlsa -> tlsa_unsupported;
                           _    -> none           %% ANY: bare NOTIMP (RFC 8482)
                       end,
            #{query => Q, rcode => notimp, aa => false,
              answers => [], ede => EdeCause}
    end.

%%====================================================================
%% Response spec builders
%%====================================================================

ok_spec(Q, RRs) ->
    #{query   => Q,
      rcode   => noerror,
      aa      => true,
      answers => RRs,
      ede     => none}.

%% AA flag: set for authoritative answers (NOERROR, NXDOMAIN — we
%% ARE authoritative for the mesh suffix); cleared for REFUSED /
%% SERVFAIL / NOTIMP (we're declining / failing, not asserting).
error_spec(Q, Rcode, EdeCause) ->
    Aa = lists:member(Rcode, [noerror, nxdomain]),
    #{query   => Q,
      rcode   => Rcode,
      aa      => Aa,
      answers => [],
      ede     => EdeCause}.

%% FORMERR for a packet that has a valid 12-byte header but zero
%% questions. Anything too short to have a header → caller drops.
formerr_response(<<Id:16, _/binary>> = Bin) when byte_size(Bin) >= 12 ->
    %% Build a minimal FORMERR with no question section.
    %% Flags: QR=1, Opcode=0, AA=0, TC=0, RD=0, RA=0, Z=0, RCODE=1.
    Flags = (1 bsl 15) bor 1,
    {ok, <<Id:16, Flags:16, 0:16, 0:16, 0:16, 0:16>>};
formerr_response(_) ->
    drop.
