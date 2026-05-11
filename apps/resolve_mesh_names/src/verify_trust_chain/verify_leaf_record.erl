%%% @doc verify_leaf_record: link 4 of the 5-link trust chain.
%%%
%%% Verifies a leaf record (one of `station_endpoint',
%%% `address_pubkey_map', `procedure_advertisement',
%%% `hosted_address_map') — signature against the `member_node'
%%% pubkey from the upstream RME, plus expiry check via record's
%%% `expires_at' if present.
%%%
%%% Tombstone detection is by-record-type: a record envelope of
%%% type 0x0C (TOMBSTONE) for the same key supersedes the leaf.
%%% The chain driver looks up tombstones separately (or the PMs
%%% invalidate the L4 cache on tombstone observation).
%%% @end
-module(verify_leaf_record).

-export([verify/3]).

-define(TYPE_STATION_ENDPOINT,        16#12).
-define(TYPE_ADDRESS_PUBKEY_MAP,      16#13).
-define(TYPE_HOSTED_ADDRESS_MAP,      16#14).
-define(TYPE_PROCEDURE_ADVERTISEMENT, 16#06).

-spec verify(LeafRecord :: map(),
             MemberPubkey :: binary(),
             Opts :: map()) ->
    {ok, VerifiedLeaf :: map()} | {error, atom()}.
verify(LeafRecord, MemberPubkey, Opts) ->
    NowMs = maps:get(now_ms, Opts, erlang:system_time(millisecond)),
    case check_envelope_key(LeafRecord, MemberPubkey) of
        ok ->
            case macula_record:verify(LeafRecord) of
                {ok, _} ->
                    case check_expiry(LeafRecord, NowMs) of
                        ok            -> {ok, LeafRecord};
                        {error, _} = E -> E
                    end;
                {error, _} ->
                    {error, sig_indeterminate}
            end;
        {error, _} = E ->
            E
    end.

check_envelope_key(#{key := K}, MemberPubkey) when K =:= MemberPubkey ->
    ok;
check_envelope_key(#{key := _}, _) ->
    %% Leaf signed by a key that isn't the endorsed member.
    {error, sig_indeterminate};
check_envelope_key(_, _) ->
    {error, sig_indeterminate}.

%% Records carry `expires_at' (epoch ms) at the envelope level.
check_expiry(#{expires_at := EA}, NowMs) when is_integer(EA), EA > NowMs ->
    ok;
check_expiry(#{expires_at := _}, _NowMs) ->
    {error, endorsement_expired};
check_expiry(_, _) ->
    %% No expires_at field — accept (some record types have
    %% indefinite lifetime).
    ok.
