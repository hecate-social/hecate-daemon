%%% @doc CT suite for synthesize_rr_set + the per-qtype modules.
%%% PLAN_DNS_OVER_MESH_PART1 §7, §9.1.
%%%
%%% Coverage:
%%%   - AAAA from a station_endpoint with v6 hosts → AAAA RRs
%%%   - AAAA when only v4 hosts advertised → nodata
%%%   - A from a station_endpoint with v4 hosts → A RRs
%%%   - SRV → `0 0 <quic_port> <station-qname>'
%%%   - TXT with alpn → one TXT RR; without alpn → nodata
%%%   - SOA from a realm_directory → one SOA RR
%%%   - TLSA → notimp; ANY → notimp; unknown qtype → nodata
%%%   - PTR / NS with no source records → nodata
%%%   - rr_ttl clamps remaining-lifetime to [min_rr_ttl, max_rr_ttl]
%%%   - station_qname → `<z32(pubkey)>._st.macula.io.'
%%% @end
-module(synthesize_rr_set_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([
    aaaa_from_station_endpoint/1,
    aaaa_nodata_when_only_v4/1,
    a_from_station_endpoint/1,
    srv_from_station_endpoint/1,
    txt_with_alpn/1,
    txt_nodata_without_alpn/1,
    soa_from_realm_directory/1,
    tlsa_is_notimp/1,
    any_is_notimp/1,
    unknown_qtype_is_nodata/1,
    ptr_nodata_without_source/1,
    ns_nodata_without_source/1,
    rr_ttl_clamps/1,
    station_qname_form/1
]).

all() ->
    [
        aaaa_from_station_endpoint,
        aaaa_nodata_when_only_v4,
        a_from_station_endpoint,
        srv_from_station_endpoint,
        txt_with_alpn,
        txt_nodata_without_alpn,
        soa_from_realm_directory,
        tlsa_is_notimp,
        any_is_notimp,
        unknown_qtype_is_nodata,
        ptr_nodata_without_source,
        ns_nodata_without_source,
        rr_ttl_clamps,
        station_qname_form
    ].

init_per_suite(Config) ->
    application:set_env(serve_dns_over_mesh, mesh_suffix, <<"macula.io.">>),
    application:set_env(serve_dns_over_mesh, min_rr_ttl, 60),
    application:set_env(serve_dns_over_mesh, max_rr_ttl, 3600),
    Config.

end_per_suite(_Config) ->
    application:unset_env(serve_dns_over_mesh, min_rr_ttl),
    application:unset_env(serve_dns_over_mesh, max_rr_ttl),
    ok.

%%====================================================================
%% Helpers — build verified_record maps
%%====================================================================

%% A station_endpoint verified record. Hosts is a list of host
%% strings; Alpn is undefined or a binary.
station_vr(StationPk, Hosts, Port, Alpn, ExpAtMs) ->
    P0 = #{ {text, <<"quic_port">>} => Port,
            {text, <<"host_advertised">>} => Hosts },
    P  = case Alpn of
             undefined -> P0;
             A -> P0#{ {text, <<"alpn">>} => {text, A} }
         end,
    #{record_type => station_endpoint,
      mri         => <<"mri:station:x">>,
      payload     => P,
      signer_pubkey => StationPk,
      chain       => [],
      expires_at  => ExpAtMs,
      version     => <<0:128>>,
      observed_at => erlang:system_time(millisecond)}.

realm_dir_vr(RealmPk, ExpAtMs) ->
    %% version = a fake UUIDv7 (48-bit ms timestamp + filler).
    Ver = <<(erlang:system_time(millisecond)):48, 0:80>>,
    #{record_type => realm_directory,
      mri         => <<"mri:realm:io.macula">>,
      payload     => #{ {text, <<"realm_id">>} => RealmPk,
                        {text, <<"name">>}     => {text, <<"Test">>},
                        {text, <<"admin_key">>}=> RealmPk },
      signer_pubkey => RealmPk,
      chain       => [],
      expires_at  => ExpAtMs,
      version     => Ver,
      observed_at => erlang:system_time(millisecond)}.

future(Ms) -> erlang:system_time(millisecond) + Ms.

%%====================================================================
%% AAAA / A
%%====================================================================

aaaa_from_station_endpoint(_Config) ->
    StPk = crypto:strong_rand_bytes(32),
    VR   = station_vr(StPk, [<<"fc00::abc">>, <<"::1">>, <<"192.0.2.7">>],
                      4433, undefined, future(120000)),
    QN   = <<"s.._st.macula.io.">>,
    {answer, RRs} = synthesize_rr_set:synth(QN, aaaa, [VR], #{}),
    %% Two v6 hosts → two AAAA RRs; the v4 host is filtered out.
    2 = length(RRs),
    [#{name := QN, type := aaaa, ttl := T, rdata := {16#fc00,0,0,0,0,0,0,16#abc}},
     #{name := QN, type := aaaa, rdata := {0,0,0,0,0,0,0,1}}] = RRs,
    true = (T >= 60 andalso T =< 120),
    ok.

aaaa_nodata_when_only_v4(_Config) ->
    StPk = crypto:strong_rand_bytes(32),
    VR   = station_vr(StPk, [<<"192.0.2.7">>], 4433, undefined, future(120000)),
    nodata = synthesize_rr_set:synth(<<"sx._st.macula.io.">>, aaaa, [VR], #{}),
    ok.

a_from_station_endpoint(_Config) ->
    StPk = crypto:strong_rand_bytes(32),
    VR   = station_vr(StPk, [<<"192.0.2.7">>, <<"::1">>], 4433, undefined, future(120000)),
    {answer, [#{type := a, rdata := {192,0,2,7}}]} =
        synthesize_rr_set:synth(<<"sx._st.macula.io.">>, a, [VR], #{}),
    ok.

%%====================================================================
%% SRV
%%====================================================================

srv_from_station_endpoint(_Config) ->
    StPk = crypto:strong_rand_bytes(32),
    VR   = station_vr(StPk, [<<"::1">>], 4433, undefined, future(120000)),
    {answer, [#{type := srv, rdata := {0, 0, 4433, Target}}]} =
        synthesize_rr_set:synth(<<"sx._st.macula.io.">>, srv, [VR], #{}),
    %% Target is the station's own _st qname.
    {ok, ExpectedTarget} =
        qname_to_mri:format(<<"mri:station:", (macula_z32:encode(StPk))/binary>>),
    Target = ExpectedTarget,
    ok.

%%====================================================================
%% TXT
%%====================================================================

txt_with_alpn(_Config) ->
    StPk = crypto:strong_rand_bytes(32),
    VR   = station_vr(StPk, [<<"::1">>], 4433, <<"h3">>, future(120000)),
    {answer, [#{type := txt, rdata := [<<"alpn=h3">>]}]} =
        synthesize_rr_set:synth(<<"sx._st.macula.io.">>, txt, [VR], #{}),
    ok.

txt_nodata_without_alpn(_Config) ->
    StPk = crypto:strong_rand_bytes(32),
    VR   = station_vr(StPk, [<<"::1">>], 4433, undefined, future(120000)),
    nodata = synthesize_rr_set:synth(<<"sx._st.macula.io.">>, txt, [VR], #{}),
    ok.

%%====================================================================
%% SOA
%%====================================================================

soa_from_realm_directory(_Config) ->
    RealmPk = crypto:strong_rand_bytes(32),
    VR      = realm_dir_vr(RealmPk, future(600000)),
    {answer, [#{type := soa, rdata := {Mname, Rname, Serial, _R, _Re, _E, _M}}]} =
        synthesize_rr_set:synth(<<"macula.io.">>, soa, [VR], #{}),
    %% MNAME = the realm root's _st qname.
    {ok, Mname} = qname_to_mri:format(
                    <<"mri:station:", (macula_z32:encode(RealmPk))/binary>>),
    <<"hostmaster.macula.io.">> = Rname,
    true = is_integer(Serial) andalso Serial > 0,
    ok.

%%====================================================================
%% notimp / nodata
%%====================================================================

tlsa_is_notimp(_Config) ->
    notimp = synthesize_rr_set:synth(<<"sx._st.macula.io.">>, tlsa, [], #{}),
    ok.

any_is_notimp(_Config) ->
    notimp = synthesize_rr_set:synth(<<"sx._st.macula.io.">>, any, [], #{}),
    ok.

unknown_qtype_is_nodata(_Config) ->
    nodata = synthesize_rr_set:synth(<<"sx._st.macula.io.">>, mx, [], #{}),
    nodata = synthesize_rr_set:synth(<<"sx._st.macula.io.">>, cname, [], #{}),
    ok.

ptr_nodata_without_source(_Config) ->
    nodata = synthesize_rr_set:synth(<<"x.ip6.arpa.">>, ptr, [], #{}),
    ok.

ns_nodata_without_source(_Config) ->
    nodata = synthesize_rr_set:synth(<<"macula.io.">>, ns, [], #{}),
    ok.

%%====================================================================
%% TTL + station_qname helpers
%%====================================================================

rr_ttl_clamps(_Config) ->
    %% Remaining lifetime far above max → clamped to 3600.
    VR1 = #{expires_at => future(99999999)},
    3600 = synthesize_rr_set:rr_ttl(VR1, #{}),
    %% Far below min (already expired) → clamped to 60.
    VR2 = #{expires_at => erlang:system_time(millisecond) - 5000},
    60 = synthesize_rr_set:rr_ttl(VR2, #{}),
    %% In range → passthrough (~120s).
    VR3 = #{expires_at => future(120000)},
    T3 = synthesize_rr_set:rr_ttl(VR3, #{}),
    true = (T3 >= 60 andalso T3 =< 121),
    ok.

station_qname_form(_Config) ->
    Pk  = crypto:strong_rand_bytes(32),
    Z32 = macula_z32:encode(Pk),
    QN  = synthesize_rr_set:station_qname(Pk),
    Expected = <<Z32/binary, "._st.macula.io.">>,
    QN = Expected,
    ok.
