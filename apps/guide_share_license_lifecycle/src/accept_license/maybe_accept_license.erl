%%% @doc Handler for accept_license_v1.
%%%
%%% Branches on `wrap_strategy`:
%%%   - `realm_key_v1` → `hecate_realm_crypto:unwrap/2` with realm
%%%   - `did_x25519_v1` → `hecate_did_crypto:unwrap_with_privkey/2`
%%%     using this daemon's X25519 private key.
%%%
%%% Plaintext CEK is immediately re-sealed via `hecate_crypto:encrypt/1`
%%% (daemon-local wrap) and stored as `accepted_cek_sealed` — the
%%% plaintext never touches disk.
%%% @end
-module(maybe_accept_license).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    case validate(Payload) of
        ok ->
            unwrap_and_build(Payload);
        {error, _} = Err ->
            Err
    end.

-spec handle(accept_license_v1:accept_license_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Cmd) ->
    handle_from_map(accept_license_v1:to_map(Cmd)).

-spec dispatch(accept_license_v1:accept_license_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    Payload = accept_license_v1:to_map(Cmd),
    LicenseId = maps:get(license_id, Payload),
    StreamId = accepted_license_aggregate:stream_id(LicenseId),
    EvoqCmd = #evoq_command{
        command_type   = accept_license_v1,
        aggregate_type = accepted_license_aggregate,
        aggregate_id   = StreamId,
        payload        = Payload#{command_type => accept_license_v1},
        metadata       = #{timestamp => erlang:system_time(millisecond)}},
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => share_licenses_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual}).

%% --- Internal ---

validate(Payload) ->
    Required = [license_id, file_id, grantee, wrap_strategy,
                wrapped_cek, issuer_did, realm,
                issued_at, expires_at],
    check_required(Required, Payload).

check_required([], _Payload) -> ok;
check_required([K | Rest], Payload) ->
    case maps:get(K, Payload, undefined) of
        undefined -> {error, {missing, K}};
        <<>>      -> {error, {empty, K}};
        _         -> check_required(Rest, Payload)
    end.

unwrap_and_build(Payload) ->
    case unwrap_cek(Payload) of
        {ok, PlaintextCek} ->
            seal_and_build(Payload, PlaintextCek);
        {error, _} = Err ->
            Err
    end.

unwrap_cek(#{wrap_strategy := realm_key_v1, wrapped_cek := WC, realm := Realm}) ->
    hecate_realm_crypto:unwrap(Realm, WC);
unwrap_cek(#{wrap_strategy := did_x25519_v1, wrapped_cek := WC}) ->
    case hecate_identity:encryption_keypair() of
        {ok, {_Pub, Priv}} ->
            hecate_did_crypto:unwrap_with_privkey(Priv, WC);
        not_initialized ->
            {error, encryption_keypair_not_ready}
    end;
unwrap_cek(_) ->
    {error, unknown_wrap_strategy}.

seal_and_build(Payload, PlaintextCek) ->
    case hecate_crypto:encrypt(PlaintextCek) of
        {ok, Sealed} ->
            AcceptedAt = erlang:system_time(millisecond),
            Map = maps:merge(Payload, #{
                accepted_cek_sealed => Sealed,
                accepted_at         => AcceptedAt}),
            {ok, Event} = license_accepted_v1:new(Map),
            {ok, [license_accepted_v1:to_map(Event)]};
        {error, _} = Err ->
            Err
    end.
