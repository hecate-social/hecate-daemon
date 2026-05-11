%%% @doc QTYPE SOA synthesiser. PLAN_DNS_OVER_MESH_PART1 §7,
%%% §3.4.12: realm-apex queries → an SOA derived from the
%%% realm_directory record. MNAME = `<z32(realm-root-pubkey)>._st.macula.io.';
%%% RNAME = `hostmaster.macula.io.'; SERIAL derived from the
%%% directory's version (UUIDv7 timestamp, seconds); the
%%% refresh/retry/expire/minimum fields get conventional defaults.
%%%
%%% Note: resolve_mri doesn't yet resolve realm-apex MRIs
%%% (`mri:realm:...' → {not_resolvable_yet, realm}), so no
%%% realm_directory verified-record reaches here for now → this
%%% returns `[]' → NODATA. It activates once resolve_mri handles
%%% the realm type (a follow-up).
%%% @end
-module(synth_soa).

-export([rrs/3]).

-define(SOA_REFRESH, 7200).
-define(SOA_RETRY,   3600).
-define(SOA_EXPIRE,  1209600).

-spec rrs(QName :: binary(), VRs :: [map()], Opts :: map()) -> [map()].
rrs(QName, VRs, Opts) ->
    case [VR || #{record_type := realm_directory} = VR <- VRs] of
        [DirVR | _] ->
            Ttl   = synthesize_rr_set:rr_ttl(DirVR, Opts),
            P     = maps:get(payload, DirVR, #{}),
            RealmPk = maps:get({text, <<"realm_id">>}, P, <<>>),
            Mname = case synthesize_rr_set:station_qname(RealmPk) of
                        undefined -> QName;
                        M         -> M
                    end,
            Rname  = <<"hostmaster.macula.io.">>,
            Serial = serial_from_version(maps:get(version, DirVR, undefined)),
            [#{name => QName, type => soa, ttl => Ttl,
               rdata => {Mname, Rname, Serial,
                         ?SOA_REFRESH, ?SOA_RETRY, ?SOA_EXPIRE, Ttl}}];
        [] ->
            []
    end.

%% UUIDv7's first 48 bits are a millisecond timestamp. Use the
%% second-resolution timestamp as the SOA serial (monotone,
%% fits in 32 bits until year ~2106). Fall back to 1 when the
%% version isn't a recognisable UUIDv7.
serial_from_version(<<Ms:48, _Rest/binary>>) when Ms > 0 ->
    (Ms div 1000) band 16#FFFFFFFF;
serial_from_version(_) ->
    1.
