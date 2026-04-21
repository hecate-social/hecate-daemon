%%% @doc PM: realm_shared_key_stored_v1 → announce identity pubkey.
%%%
%%% Fires once the daemon has fetched + sealed K_realm — that's the
%%% moment we're fully a functioning realm member. Announces our
%%% X25519 encryption pubkey to the realm directory so other members
%%% can wrap CEKs for us (DID-scope licenses).
%%%
%%% Idempotent at the aggregate layer — the aggregate rejects a
%%% second announce_identity_public_key command after the
%%% IDENTITY_PUBKEY_ANNOUNCED bit is set, so even evoq replay or
%%% rotation (which re-stores K_realm) is a safe no-op.
%%% @end
-module(on_realm_shared_key_stored_announce_public_key).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"realm_shared_key_stored_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    MembershipId = gf(membership_id, Data),
    announce_if_ready(MembershipId),
    {ok, State}.

%%%===================================================================
%%% Internal
%%%===================================================================

announce_if_ready(undefined) ->
    logger:warning("[pm.announce_pubkey] missing membership_id");
announce_if_ready(MembershipId) ->
    case hecate_identity:get_mri() of
        {ok, Mri} ->
            fetch_pubkey_and_announce(MembershipId, Mri);
        not_initialized ->
            logger:warning("[pm.announce_pubkey] identity not initialized; skipping")
    end.

fetch_pubkey_and_announce(MembershipId, Mri) ->
    case hecate_identity:get_encryption_public_key() of
        {ok, Pub} ->
            dispatch_announce(MembershipId, Mri, Pub);
        not_initialized ->
            logger:warning("[pm.announce_pubkey] encryption pubkey not ready")
    end.

dispatch_announce(MembershipId, Mri, Pub) ->
    case announce_identity_public_key_v1:new(#{
        membership_id         => MembershipId,
        mri                   => Mri,
        encryption_public_key => Pub
    }) of
        {ok, Cmd} ->
            log_result(Mri, maybe_announce_identity_public_key:dispatch(Cmd));
        {error, Reason} ->
            logger:warning("[pm.announce_pubkey] cmd build failed: ~p", [Reason])
    end.

log_result(Mri, {ok, _V, _Events}) ->
    logger:info("[pm.announce_pubkey] announced ~s", [Mri]);
log_result(_Mri, {error, already_announced}) ->
    ok;
log_result(Mri, {error, Reason}) ->
    logger:info("[pm.announce_pubkey] ~s skipped: ~p", [Mri, Reason]).

gf(Key, Data) when is_map(Data) ->
    maps:get(Key, Data, maps:get(atom_to_binary(Key, utf8), Data, undefined));
gf(_Key, _Data) ->
    undefined.
