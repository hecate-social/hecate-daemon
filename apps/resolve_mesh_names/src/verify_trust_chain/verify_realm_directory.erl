%%% @doc verify_realm_directory: link 2 of the 5-link trust chain.
%%%
%%% Verifies a realm_directory record's signature against the
%%% realm_root_pubkey from FRTL, returns the directory payload
%%% so the chain driver can extract `admin_key' (which acts as
%%% the trust delegate / endorsement signer in the 4.x SDK).
%%%
%%% PART1 §5.1's `trust_delegates' + `coverage_proof_pointer' are
%%% conceptual; the SDK 4.x realm_directory payload has:
%%%   `realm_id'   : 32-byte pubkey
%%%   `name'       : binary (e.g., <<"io.macula">>)
%%%   `admin_key'  : 32-byte pubkey (the realm admin who signs RMEs)
%%%   `created_at' : epoch ms
%%%   `policy_url' : optional binary
%%%
%%% A realm with delegated trust (`trust_delegates' list) would
%%% need a SDK schema bump (macula 4.4.0 candidate). Until then
%%% endorsements are signed by either the realm root itself or
%%% by the admin_key.
%%% @end
-module(verify_realm_directory).

-export([verify/2]).

-spec verify(DirRecord :: map(), RealmRootPubkey :: binary()) ->
    {ok, DirPayload :: map()} | {error, atom()}.
verify(DirRecord, RealmRootPubkey) ->
    case check_envelope_key(DirRecord, RealmRootPubkey) of
        ok ->
            case macula_record:verify(DirRecord) of
                {ok, _} -> {ok, payload(DirRecord)};
                {error, _} -> {error, realm_dir_bogus}
            end;
        {error, _} = E ->
            E
    end.

check_envelope_key(#{key := K}, RealmRootPubkey) when K =:= RealmRootPubkey ->
    ok;
check_envelope_key(#{key := _}, _) ->
    {error, realm_dir_bogus};
check_envelope_key(_, _) ->
    {error, realm_dir_unavailable}.

payload(#{payload := P}) when is_map(P) -> P;
payload(_) -> #{}.
