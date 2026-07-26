%%% @doc Application module for guide_realm_cert_lifecycle.
%%%
%%% Owns the realm-cert acquisition lifecycle on the daemon side. On
%%% first boot the supervisor starts a bootstrap worker that checks
%%% the local cert state (replayed from `realm_cert_store') and, if
%%% no valid cert is present, dispatches `acquire_provisional_cert_v1'.
%%% The handler does an HTTPS POST to macula-realm's
%%% `/api/v1/provisional/issue', writes the cert + key + chain to
%%% `~/.hecate/realm-cert/', and records
%%% `provisional_cert_acquired_v1' for the audit trail.
%%%
%%% Renewal (when cert is within renewal window) lands in a follow-up
%%% slice (`renew_provisional_cert/`).
%%%
%%% Wiring the cert into the macula handshake (so the daemon presents
%%% it on every QUIC peering) is also a follow-up slice; for now the
%%% files sit on disk and the audit event records that acquisition
%%% succeeded.
%%% @end
-module(guide_realm_cert_lifecycle_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    guide_realm_cert_lifecycle_sup:start_link().

stop(_State) ->
    ok.
