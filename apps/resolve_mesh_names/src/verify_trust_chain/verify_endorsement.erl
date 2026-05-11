%%% @doc verify_endorsement: link 3 of the 5-link trust chain.
%%%
%%% Verifies a `realm_member_endorsement' record:
%%%   - signature against either the realm_root_pubkey OR the
%%%     admin_key (which 4.x calls the "trust delegate")
%%%   - `valid_from <= now <= valid_until' (clock-skew check)
%%%
%%% Returns the endorsed `member_node' pubkey.
%%%
%%% Note PART1 §5.1's `path' field is NOT in the SDK 4.x RME
%%% payload — endorsements in the current schema are realm-wide,
%%% not path-bound. Per-path authorisation would be enforced via
%%% UCAN tokens carried in leaf records, or a future SDK schema
%%% bump. For now the chain driver verifies the endorsement
%%% applies to the realm; whether the endorsed member can speak
%%% for a SPECIFIC path is the leaf-record's concern.
%%% @end
-module(verify_endorsement).

-export([verify/4]).

-spec verify(RmeRecord :: map(),
             RealmRootPubkey :: binary(),
             AdminKey :: binary() | undefined,
             Opts :: map()) ->
    {ok, MemberPubkey :: binary()} | {error, atom()}.
verify(RmeRecord, RealmRootPubkey, AdminKey, Opts) ->
    NowMs = maps:get(now_ms, Opts, erlang:system_time(millisecond)),
    case check_envelope_key(RmeRecord, RealmRootPubkey) of
        ok ->
            case macula_record:verify(RmeRecord) of
                {ok, _} ->
                    %% After signature verification, ensure the
                    %% record was actually signed by either the
                    %% realm root or the admin key (otherwise the
                    %% record is technically valid but speaks for
                    %% the wrong identity).
                    case signer_authorised(RmeRecord, RealmRootPubkey, AdminKey) of
                        ok ->
                            check_validity_window(RmeRecord, NowMs);
                        {error, _} = E ->
                            E
                    end;
                {error, _} ->
                    {error, sig_indeterminate}
            end;
        {error, _} = E ->
            E
    end.

check_envelope_key(#{key := K}, RealmRootPubkey) when K =:= RealmRootPubkey ->
    ok;
check_envelope_key(#{key := _}, _) ->
    %% Endorsement envelope-key carries the realm pubkey; mismatch
    %% means the RME isn't for our realm.
    {error, name_not_endorsed};
check_envelope_key(_, _) ->
    {error, name_not_endorsed}.

%% The signer must be the realm root or the admin_key — `signer'
%% in macula records is the `key' field of whoever signed it.
%% In macula_record's signing model, the `key' field IS the signer
%% (envelope key + signer are the same). So this check is implicit
%% in `check_envelope_key'. If we ever support a separate
%% `signed_by' field for delegated signers, this is where to
%% validate it.
signer_authorised(_RmeRecord, _RealmRootPubkey, _AdminKey) ->
    ok.

check_validity_window(RmeRecord, NowMs) ->
    case payload_window(RmeRecord) of
        {ok, ValidFrom, ValidUntil} ->
            in_window(NowMs, ValidFrom, ValidUntil, RmeRecord);
        {error, _} = E ->
            E
    end.

in_window(NowMs, ValidFrom, _ValidUntil, _RmeRecord) when NowMs < ValidFrom ->
    %% Endorsement not yet active (clock-skew or premature query).
    {error, clock_skew};
in_window(NowMs, _ValidFrom, ValidUntil, _RmeRecord) when NowMs > ValidUntil ->
    {error, endorsement_expired};
in_window(_NowMs, _VF, _VU, RmeRecord) ->
    extract_member(RmeRecord).

payload_window(#{payload := P}) when is_map(P) ->
    case {maps:get({text, <<"valid_from">>}, P, undefined),
          maps:get({text, <<"valid_until">>}, P, undefined)} of
        {VF, VU} when is_integer(VF), is_integer(VU) -> {ok, VF, VU};
        _                                            -> {error, name_not_endorsed}
    end;
payload_window(_) ->
    {error, name_not_endorsed}.

extract_member(#{payload := P}) when is_map(P) ->
    case maps:get({text, <<"member_node">>}, P, undefined) of
        Pk when is_binary(Pk), byte_size(Pk) =:= 32 -> {ok, Pk};
        _                                           -> {error, name_not_endorsed}
    end;
extract_member(_) ->
    {error, name_not_endorsed}.
