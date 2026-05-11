%%% @doc EDE (Extended DNS Errors, RFC 8914) encoder.
%%%
%%% Maps an internal failure-cause atom — the `{error, Reason}'
%%% atoms `resolve_mesh_names' returns, plus the bridge-local ones
%%% from PLAN_DNS_OVER_MESH_PART1 §6 — to:
%%%   - an EDE INFO-CODE (16-bit, RFC 8914 §5.2 registry)
%%%   - an EXTRA-TEXT string (UTF-8, human-friendly)
%%%
%%% `option/2' returns the wire-encoded OPT-OPTION ready to be
%%% appended inside the OPT pseudo-RR's RDATA:
%%%   OPTION-CODE(2) = 15 (EDE) ‖ OPTION-LENGTH(2) ‖ INFO-CODE(2) ‖ EXTRA-TEXT
%%%
%%% `info/1' is the lookup without wire encoding (for tests + the
%%% rcode-mapping code).
%%% @end
-module(compose_ede).

-export([option/2, info/1]).

-define(OPT_CODE_EDE, 15).

%% @doc Wire-encoded EDE OPT-OPTION for the given cause. `Detail'
%% is appended to the canonical extra-text when present (e.g., a
%% realm-id for `realm_not_trusted'). Returns `<<>>' for `none'
%% (no EDE — the answer was clean).
-spec option(Cause :: atom() | tuple(), Detail :: binary() | undefined) ->
    binary().
option(none, _Detail) ->
    <<>>;
option(Cause, Detail) ->
    {InfoCode, BaseText} = info(Cause),
    Text = case Detail of
               undefined -> BaseText;
               <<>>      -> BaseText;
               D when is_binary(D) -> <<BaseText/binary, ":", D/binary>>
           end,
    OptData = <<InfoCode:16, Text/binary>>,
    <<?OPT_CODE_EDE:16, (byte_size(OptData)):16, OptData/binary>>.

%% @doc INFO-CODE + canonical extra-text for a cause atom (or a
%% tagged tuple like `{not_resolvable_yet, Type}'). Unknown causes
%% get the generic "Other" code (0).
-spec info(Cause :: atom() | tuple()) -> {non_neg_integer(), binary()}.
%% --- from resolve_mesh_names' reason() type ---
info(no_trust_root)         -> {18, <<"no_trust_root">>};            %% Prohibited
info(trust_list_unavailable)-> {22, <<"trust_list_unavailable">>};   %% No Reachable Authority
info(trust_list_stale)      -> {22, <<"trust_list_stale">>};
info(realm_not_trusted)     -> {18, <<"realm_not_trusted">>};
info(realm_dir_unavailable) -> {22, <<"realm_dir_unavailable">>};
info(realm_dir_bogus)       -> {6,  <<"realm_dir_bogus">>};          %% DNSSEC Bogus
info(name_not_endorsed)     -> {9,  <<"name_not_endorsed">>};        %% DNSSEC Missing (analogue)
info(coverage_unknown)      -> {22, <<"coverage_unknown">>};
info(endorsement_expired)   -> {26, <<"endorsement_expired">>};     %% Stale Answer (analogue)
info(name_revoked)          -> {6,  <<"name_revoked">>};
info(sig_indeterminate)     -> {6,  <<"sig_indeterminate">>};
info(delegation_invalid)    -> {6,  <<"delegation_invalid">>};
info(clock_skew)            -> {23, <<"clock_skew">>};               %% Stale NXDOMAIN (analogue)
info(dht_timeout)           -> {22, <<"dht_timeout">>};
info(lookup_dedup_timeout)  -> {22, <<"dht_timeout">>};
info(station_not_announced) -> {22, <<"station_not_announced">>};
info(integrity_violation)   -> {6,  <<"integrity_violation">>};
%% --- bridge-local causes (PART1 §6) ---
info(zone_transfer_disabled)-> {18, <<"zone_transfer_disabled">>};
info(name_too_long)         -> {0,  <<"name_too_long">>};
info(not_in_mesh_suffix)    -> {0,  <<"not_in_mesh_suffix">>};
info(malformed_qname)       -> {0,  <<"malformed_qname">>};
info(tlsa_unsupported)      -> {0,  <<"tlsa_unsupported">>};
info({not_resolvable_yet, _}) -> {0, <<"not_resolvable_yet">>};
%% --- catch-all ---
info(_)                     -> {0,  <<"other">>}.
