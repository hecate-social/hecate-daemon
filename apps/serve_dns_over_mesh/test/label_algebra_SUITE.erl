%%% @doc CT suite for the qname↔MRI label algebra. PLAN PART1 §3 +
%%% §3.4 edge cases.
%%%
%%% Coverage:
%%%   - All 8 §3.3 worked examples round-trip (forward + reverse)
%%%   - Per-type forward direction
%%%   - Edge cases: malformed qnames, name-too-long, non-mesh suffix
%%%   - Reverse direction edge cases
%%%
%%% Cases that need macula 4.3.0 (z32 codec, station MRI type) are
%%% skipped with `{skip, ...}' until the SDK ships.
%%% @end
-module(label_algebra_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([
    realm_apex/1,
    org_only/1,
    user/1,
    app/1,
    service_under_app/1,
    device/1,
    proc_dotted/1,
    topic_dotted/1,
    station_roundtrip/1,
    reverse_v6_signals_lookup_required/1,
    rejects_non_mesh_suffix/1,
    rejects_oversized_qname/1,
    rejects_empty_qname/1,
    accepts_trailing_dot_or_not/1,
    case_insensitive_input/1
]).

all() ->
    [
        realm_apex,
        org_only,
        user,
        app,
        service_under_app,
        device,
        proc_dotted,
        topic_dotted,
        station_roundtrip,
        reverse_v6_signals_lookup_required,
        rejects_non_mesh_suffix,
        rejects_oversized_qname,
        rejects_empty_qname,
        accepts_trailing_dot_or_not,
        case_insensitive_input
    ].

init_per_suite(Config) ->
    application:set_env(serve_dns_over_mesh, mesh_suffix, <<"macula.io.">>),
    Config.

end_per_suite(_Config) ->
    ok.

%% Round-trip helper: forward (qname → MRI) AND reverse (MRI → qname)
%% must both produce the expected value.
roundtrip(QName, ExpectedMri) ->
    {ok, ExpectedMri} = qname_to_mri:resolve(QName),
    {ok, QName} = qname_to_mri:format(ExpectedMri),
    ok.

%%====================================================================
%% PART1 §3.3 worked examples — round-trip both directions
%%====================================================================

realm_apex(_Config) ->
    roundtrip(<<"macula.io.">>, <<"mri:realm:io.macula">>).

org_only(_Config) ->
    roundtrip(<<"acme.macula.io.">>, <<"mri:org:io.macula/acme">>).

user(_Config) ->
    roundtrip(<<"alice._u.acme.macula.io.">>,
              <<"mri:user:io.macula/acme/alice">>).

app(_Config) ->
    roundtrip(<<"counter._a.acme.macula.io.">>,
              <<"mri:app:io.macula/acme/counter">>).

service_under_app(_Config) ->
    %% Two-discriminator nesting: service-under-app-under-org.
    roundtrip(<<"api._s.counter._a.acme.macula.io.">>,
              <<"mri:service:io.macula/acme/counter/api">>).

device(_Config) ->
    roundtrip(<<"cab-01._d.citypower.macula.io.">>,
              <<"mri:device:io.macula/citypower/cab-01">>).

proc_dotted(_Config) ->
    %% PLAN §3.4.2: dotted segment for proc.
    roundtrip(<<"get.users.api._p.acme.macula.io.">>,
              <<"mri:proc:io.macula/acme/api.users.get">>).

topic_dotted(_Config) ->
    roundtrip(<<"placed.orders._t.acme.macula.io.">>,
              <<"mri:topic:io.macula/acme/orders.placed">>).

%%====================================================================
%% Special-case stubs (gated on SDK / lookup desk)
%%====================================================================

station_roundtrip(_Config) ->
    %% Generate a real Ed25519-pubkey-sized random buffer, z32-encode
    %% it, build the station qname, parse it, and round-trip the
    %% MRI back to the qname. Verifies the full bridge ↔ macula 4.3.0
    %% integration: z32 codec + station MRI type + qname_station's
    %% special case in the dispatcher.
    Pubkey = crypto:strong_rand_bytes(32),
    Z32 = macula_z32:encode(Pubkey),
    QName = <<Z32/binary, "._st.macula.io.">>,
    ExpectedMri = <<"mri:station:", Z32/binary>>,
    {ok, ExpectedMri} = qname_to_mri:resolve(QName),
    {ok, QName} = qname_to_mri:format(ExpectedMri),
    ok.

reverse_v6_signals_lookup_required(_Config) ->
    %% qname_reverse_v6 needs the lookup desk (DHT find on
    %% address_pubkey_map). Without it, signal that upstream
    %% routing is required.
    Q = <<"c.b.a.0.0.0.0.0.0.0.0.0.0.0.0.0.f.f.0.c.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa.">>,
    {error, reverse_v6_lookup_required} = qname_to_mri:resolve(Q),
    ok.

%%====================================================================
%% Edge cases
%%====================================================================

rejects_non_mesh_suffix(_Config) ->
    %% Anything outside the mesh_suffix → not_in_mesh_suffix error.
    %% The bridge then maps this to REFUSED at the wire layer.
    {error, not_in_mesh_suffix} =
        qname_to_mri:resolve(<<"alice._u.acme.example.com.">>),
    {error, not_in_mesh_suffix} =
        qname_to_mri:resolve(<<"random.qname.">>),
    ok.

rejects_oversized_qname(_Config) ->
    %% RFC 1035 §2.3.4: 255-octet cap.
    Big = list_to_binary(lists:duplicate(300, $a)),
    {error, name_too_long} = qname_to_mri:resolve(Big),
    ok.

rejects_empty_qname(_Config) ->
    {error, malformed_qname} = qname_to_mri:resolve(<<>>),
    ok.

accepts_trailing_dot_or_not(_Config) ->
    %% Input normalisation: with-trailing-dot and without should
    %% both resolve to the same MRI. (Reverse always emits with dot.)
    Expected = <<"mri:user:io.macula/acme/alice">>,
    {ok, Expected} = qname_to_mri:resolve(<<"alice._u.acme.macula.io.">>),
    {ok, Expected} = qname_to_mri:resolve(<<"alice._u.acme.macula.io">>),
    ok.

case_insensitive_input(_Config) ->
    %% PART1 §3.4.15: DNS is case-insensitive on label compare.
    %% Lowercased before dispatch.
    Expected = <<"mri:user:io.macula/acme/alice">>,
    {ok, Expected} = qname_to_mri:resolve(<<"Alice._U.ACME.macula.io.">>),
    ok.
