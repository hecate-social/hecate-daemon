%%% @doc verify_frtl: link 1 of the 5-link trust chain.
%%%
%%% Verifies the foundation_realm_trust_list signature against the
%%% known foundation pubkey, checks `valid_until > now + grace',
%%% returns the trusted realm pubkey list.
%%%
%%% Signature verification delegates to `macula_record:verify/1'
%%% (Ed25519). FRTL payload shape (per the macula 4.x SDK):
%%%   `realms_trusted'  : [realm_pubkey :: <<_:32/binary>>]
%%%   `realms_revoked'  : [realm_pubkey :: <<_:32/binary>>]
%%%   `version'         : binary
%%%   `valid_until'     : epoch ms
%%%
%%% Note the SDK schema diverges from PLAN_RESOLVE_MESH_NAMES_PART1
%%% §5.1's conceptual `{realm_id → realm_root_pubkey}' mapping —
%%% the SDK uses a flat list of trusted realm pubkeys. The mapping
%%% from dotted-string realm-id to realm pubkey is established by
%%% querying realm_directory records for each trusted pubkey and
%%% checking `payload.name'. This module handles the signature +
%%% expiry; the realm-mapping happens in the chain driver.
%%% @end
-module(verify_frtl).

-export([verify/3]).

%% @doc Verify an FRTL record against a known foundation pubkey.
%% Returns the parsed payload on success; typed error otherwise.
-spec verify(FrtlRecord :: map(),
             FoundationPubkey :: binary(),
             Opts :: map()) ->
    {ok, FrtlPayload :: map()} | {error, atom()}.
verify(FrtlRecord, FoundationPubkey, Opts) ->
    GraceMs = maps:get(grace_window_ms, Opts, 0),
    NowMs   = maps:get(now_ms, Opts, erlang:system_time(millisecond)),
    case check_envelope_key(FrtlRecord, FoundationPubkey) of
        ok ->
            case macula_record:verify(FrtlRecord) of
                {ok, _} ->
                    check_validity(FrtlRecord, NowMs, GraceMs);
                {error, _} ->
                    {error, trust_list_unavailable}
            end;
        {error, _} = E ->
            E
    end.

%% The FRTL's envelope key MUST equal the foundation pubkey we
%% trust — otherwise we're being handed an FRTL signed by some
%% other foundation we don't anchor.
check_envelope_key(#{key := K}, FoundationPubkey) when K =:= FoundationPubkey ->
    ok;
check_envelope_key(#{key := _}, _) ->
    {error, trust_list_unavailable};
check_envelope_key(_, _) ->
    {error, trust_list_unavailable}.

check_validity(FrtlRecord, NowMs, GraceMs) ->
    case payload_valid_until(FrtlRecord) of
        {ok, ValidUntil} ->
            case ValidUntil + GraceMs > NowMs of
                true  -> {ok, payload(FrtlRecord)};
                false -> {error, trust_list_stale}
            end;
        {error, _} = E ->
            E
    end.

payload(#{payload := P}) when is_map(P) -> P;
payload(_) -> #{}.

payload_valid_until(#{payload := P}) when is_map(P) ->
    case maps:get({text, <<"valid_until">>}, P, undefined) of
        VU when is_integer(VU), VU > 0 -> {ok, VU};
        _                              -> {error, realm_dir_bogus}
    end;
payload_valid_until(_) ->
    {error, realm_dir_bogus}.
