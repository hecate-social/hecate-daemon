%%% @doc Boot-time + periodic catch-up for Phase D share-licenses.
%%%
%%% Mirrors `catch_up_realm_keys` in shape. Reads the realm server's
%%% `io.macula.licenses.replay_events_v1` RPC per joined realm, page
%%% by page from the last saved offset, and dispatches the matching
%%% local command for each event:
%%%
%%%   - `license_issued_v1`         → `accept_license_v1` (if own MRI)
%%%   - `share_license_revoked_v1`  → `end_license_v1`
%%%   - `license_rewrapped_v1`      → `receive_license_rewrap_v1`
%%%
%%% After a successful sweep, stamps `last_license_catchup_at` for the
%%% realm via `hecate_license_guard:stamp_catchup/1`. The open-path
%%% staleness guard consults this timestamp to refuse decryption when
%%% state is too old.
%%%
%%% Position is persisted via `mesh_catch_up:save_position/2` keyed on
%%% `<<"licenses-", Realm/binary>>` — matching the replay RPC's stream
%%% naming on the realm server.
%%%
%%% Runs every 3 minutes — tighter than K_realm catch-up because
%%% security-critical. Failures are logged and don't halt the sweep;
%%% one realm's RPC failure does not affect the others.
%%% @end
-module(catch_up_realm_licenses).
-behaviour(gen_server).

-include_lib("guide_realm_memberships/include/membership_status.hrl").

-export([start_link/0, scan_now/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% ~3 minutes between sweeps. Security-critical: revocations and
%% rewraps should heal quickly after reconnect.
-define(SCAN_INTERVAL_MS,   3 * 60 * 1000).
%% Poll interval while waiting for mesh activation at boot.
-define(ACTIVATION_POLL_MS, 3 * 1000).
%% Per-RPC page size.
-define(BATCH_SIZE,         500).
%% Replay RPC procedure name (realm server advertises this).
-define(REPLAY_PROC,        <<"io.macula.licenses.replay_events_v1">>).

-record(state, {
    timer_ref :: reference() | undefined
}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec scan_now() -> ok.
scan_now() ->
    gen_server:cast(?MODULE, scan_now).

%%====================================================================
%% gen_server
%%====================================================================

init([]) ->
    mesh_catch_up:init_position_table(),
    self() ! check_activation,
    {ok, #state{}}.

handle_call(_Msg, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(scan_now, State) ->
    scan_realms(),
    {noreply, State}.

handle_info(check_activation, State) ->
    handle_activation(mesh_activated(), State);

handle_info(periodic_scan, State) ->
    scan_realms(),
    {noreply, State#state{timer_ref = schedule_next()}};

handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, #state{timer_ref = Ref}) when is_reference(Ref) ->
    erlang:cancel_timer(Ref),
    ok;
terminate(_Reason, _State) ->
    ok.

%%====================================================================
%% Internal
%%====================================================================

handle_activation(true, State) ->
    logger:info("[catch_up.realm_licenses] mesh activated, running initial scan"),
    scan_realms(),
    {noreply, State#state{timer_ref = schedule_next()}};
handle_activation(false, State) ->
    erlang:send_after(?ACTIVATION_POLL_MS, self(), check_activation),
    {noreply, State}.

mesh_activated() ->
    case erlang:whereis(hecate_mesh_client) of
        undefined -> false;
        _Pid      -> hecate_mesh:is_activated()
    end.

schedule_next() ->
    erlang:send_after(?SCAN_INTERVAL_MS, self(), periodic_scan).

scan_realms() ->
    case own_mri() of
        undefined ->
            logger:debug("[catch_up.realm_licenses] identity not ready, skipping");
        OwnMri ->
            scan_realms(OwnMri)
    end.

scan_realms(OwnMri) ->
    case safe_list_confirmed() of
        {ok, Memberships} ->
            lists:foreach(
                fun(M) -> maybe_catch_up_membership(M, OwnMri) end,
                Memberships);
        {error, Reason} ->
            logger:warning("[catch_up.realm_licenses] list_confirmed failed: ~p",
                           [Reason])
    end.

maybe_catch_up_membership(#{status := Status} = M, OwnMri) ->
    Confirmed = evoq_bit_flags:has(Status, ?MEMBERSHIP_CONFIRMED),
    Ended     = evoq_bit_flags:has(Status, ?MEMBERSHIP_ENDED),
    case {Confirmed, Ended} of
        {true, false} -> catch_up_realm(resolve_realm(M), OwnMri);
        _             -> ok
    end;
maybe_catch_up_membership(_, _OwnMri) ->
    ok.

catch_up_realm(undefined, _OwnMri) ->
    ok;
catch_up_realm(Realm, OwnMri) ->
    StreamKey = stream_key(Realm),
    Offset = mesh_catch_up:get_position(StreamKey),
    catch_up_loop(Realm, OwnMri, StreamKey, Offset, 0).

catch_up_loop(Realm, OwnMri, StreamKey, Offset, Processed) ->
    Args = #{<<"realm">> => Realm,
             <<"since">> => Offset,
             <<"limit">> => ?BATCH_SIZE},
    case hecate_mesh:call(?REPLAY_PROC, Args, 30000) of
        {ok, #{<<"events">> := Events, <<"has_more">> := HasMore}}
          when is_list(Events) ->
            lists:foreach(
                fun(Evt) -> dispatch_event(Evt, Realm, OwnMri) end,
                Events),
            Count = length(Events),
            NewOffset = Offset + Count,
            mesh_catch_up:save_position(StreamKey, NewOffset),
            case HasMore of
                true ->
                    catch_up_loop(Realm, OwnMri, StreamKey, NewOffset,
                                   Processed + Count);
                _ ->
                    finish_sweep(Realm, Processed + Count)
            end;
        {ok, #{<<"events">> := []}} ->
            finish_sweep(Realm, Processed);
        {ok, Other} ->
            logger:warning("[catch_up.realm_licenses] unexpected response realm=~s: ~p",
                           [Realm, Other]),
            finish_sweep(Realm, Processed);
        {error, Reason} ->
            logger:info("[catch_up.realm_licenses] realm=~s replay RPC failed: ~p "
                        "(processed ~b so far)",
                        [Realm, Reason, Processed])
    end.

%% @private Stamp the per-realm catch-up timestamp and log.
%% Only fires when the RPC returned successfully (including zero new
%% events) — a network failure mid-sweep leaves the timestamp as it
%% was so the staleness guard refuses the open path until the next
%% successful sweep.
finish_sweep(Realm, Count) ->
    hecate_license_guard:stamp_catchup(Realm),
    log_done(Realm, Count).

log_done(_Realm, 0) -> ok;
log_done(Realm, N) ->
    logger:info("[catch_up.realm_licenses] realm=~s caught up ~b event(s)",
                [Realm, N]).

%% Event dispatch — matches on the envelope's `event_type`.

dispatch_event(#{<<"event_type">> := <<"license_issued_v1">>} = Evt, Realm, OwnMri) ->
    dispatch_issued(extract_data(Evt), Realm, OwnMri);
dispatch_event(#{event_type := <<"license_issued_v1">>} = Evt, Realm, OwnMri) ->
    dispatch_issued(extract_data(Evt), Realm, OwnMri);

dispatch_event(#{<<"event_type">> := <<"share_license_revoked_v1">>} = Evt, _Realm, OwnMri) ->
    dispatch_revoked(extract_data(Evt), OwnMri);
dispatch_event(#{event_type := <<"share_license_revoked_v1">>} = Evt, _Realm, OwnMri) ->
    dispatch_revoked(extract_data(Evt), OwnMri);

dispatch_event(#{<<"event_type">> := <<"license_rewrapped_v1">>} = Evt, _Realm, _OwnMri) ->
    dispatch_rewrapped(extract_data(Evt));
dispatch_event(#{event_type := <<"license_rewrapped_v1">>} = Evt, _Realm, _OwnMri) ->
    dispatch_rewrapped(extract_data(Evt));

dispatch_event(Other, _Realm, _OwnMri) ->
    logger:debug("[catch_up.realm_licenses] unknown event type: ~p",
                 [event_type_of(Other)]),
    ok.

dispatch_issued(Data, Realm, OwnMri) ->
    Grantee = gf(grantee, Data),
    case matches_grantee(Grantee, OwnMri) of
        true  -> do_dispatch_accept(Data, Realm);
        false -> ok
    end.

do_dispatch_accept(Data, Realm) ->
    Payload = #{
        license_id      => gf(license_id, Data),
        file_id         => gf(file_id,    Data),
        grantee         => gf(grantee,    Data),
        wrap_strategy   => wrap_strategy_atom(gf(wrap_strategy, Data)),
        wrapped_cek     => decode_maybe_base64(gf(wrapped_cek, Data)),
        k_realm_version => gf(k_realm_version, Data),
        issuer_did      => gf(issuer_did, Data),
        realm           => Realm,
        issued_at       => gf(issued_at, Data),
        expires_at      => gf(expires_at, Data)
    },
    case accept_license_v1:new(Payload) of
        {ok, Cmd} ->
            log_accept_result(gf(license_id, Data),
                              maybe_accept_license:dispatch(Cmd));
        {error, Reason} ->
            logger:info("[catch_up.realm_licenses] accept cmd build failed: ~p",
                        [Reason])
    end.

log_accept_result(LicenseId, {ok, _V, _Events}) ->
    logger:info("[catch_up.realm_licenses] caught-up accept license=~s", [LicenseId]);
log_accept_result(LicenseId, {error, already_accepted}) ->
    logger:debug("[catch_up.realm_licenses] idempotent accept license=~s", [LicenseId]);
log_accept_result(LicenseId, {error, Reason}) ->
    logger:info("[catch_up.realm_licenses] accept dispatch error license=~s: ~p",
                [LicenseId, Reason]).

dispatch_revoked(Data, OwnMri) ->
    Grantee = gf(grantee, Data),
    case matches_grantee(Grantee, OwnMri) of
        true  -> do_dispatch_end(Data);
        false -> ok
    end.

do_dispatch_end(Data) ->
    LicenseId = gf(license_id, Data),
    Reason    = normalize_reason(gf(reason, Data)),
    case LicenseId of
        undefined ->
            logger:info("[catch_up.realm_licenses] revoked replay missing license_id");
        _ ->
            case end_license_v1:new(#{license_id => LicenseId,
                                       reason     => Reason}) of
                {ok, Cmd} ->
                    log_end_result(LicenseId, maybe_end_license:dispatch(Cmd));
                {error, E} ->
                    logger:info("[catch_up.realm_licenses] end cmd build failed: ~p", [E])
            end
    end.

log_end_result(LicenseId, {ok, _V, _Events}) ->
    logger:info("[catch_up.realm_licenses] caught-up end license=~s", [LicenseId]);
log_end_result(LicenseId, {error, license_ended}) ->
    logger:debug("[catch_up.realm_licenses] idempotent end license=~s", [LicenseId]);
log_end_result(LicenseId, {error, Reason}) ->
    logger:info("[catch_up.realm_licenses] end dispatch error license=~s: ~p",
                [LicenseId, Reason]).

%% --- Rewrap replay ---

dispatch_rewrapped(Data) ->
    LicenseId = gf(license_id, Data),
    case {LicenseId, gf(new_wrapped_cek, Data), gf(new_k_realm_version, Data)} of
        {undefined, _, _} ->
            logger:info("[catch_up.realm_licenses] rewrap replay missing license_id");
        {_, undefined, _} ->
            logger:info("[catch_up.realm_licenses] rewrap replay missing new_wrapped_cek license=~s",
                        [LicenseId]);
        {_, _, undefined} ->
            logger:info("[catch_up.realm_licenses] rewrap replay missing new_k_realm_version license=~s",
                        [LicenseId]);
        {_, Wrapped, Version} ->
            do_dispatch_rewrap(LicenseId, decode_maybe_base64(Wrapped), Version, Data)
    end.

do_dispatch_rewrap(LicenseId, NewWrappedCek, NewVersion, Data) ->
    Payload = #{
        license_id          => LicenseId,
        new_wrapped_cek     => NewWrappedCek,
        new_k_realm_version => NewVersion,
        batch_id            => gf(batch_id, Data),
        rewrapped_at        => gf(rewrapped_at, Data)
    },
    case receive_license_rewrap_v1:new(Payload) of
        {ok, Cmd} ->
            log_rewrap_result(LicenseId,
                              maybe_receive_license_rewrap:dispatch(Cmd));
        {error, Reason} ->
            logger:info("[catch_up.realm_licenses] rewrap cmd build failed: ~p", [Reason])
    end.

log_rewrap_result(LicenseId, {ok, _V, _Events}) ->
    logger:info("[catch_up.realm_licenses] caught-up rewrap license=~s", [LicenseId]);
log_rewrap_result(LicenseId, {error, stale_rewrap}) ->
    logger:debug("[catch_up.realm_licenses] idempotent rewrap license=~s", [LicenseId]);
log_rewrap_result(LicenseId, {error, license_not_accepted}) ->
    logger:debug("[catch_up.realm_licenses] skip rewrap for unaccepted license=~s", [LicenseId]);
log_rewrap_result(LicenseId, {error, license_ended}) ->
    logger:debug("[catch_up.realm_licenses] skip rewrap for ended license=~s", [LicenseId]);
log_rewrap_result(LicenseId, {error, Reason}) ->
    logger:info("[catch_up.realm_licenses] rewrap dispatch error license=~s: ~p",
                [LicenseId, Reason]).

%% --- Helpers ---

stream_key(Realm) -> <<"licenses-", Realm/binary>>.

own_mri() ->
    case erlang:whereis(hecate_identity) of
        undefined -> undefined;
        _ ->
            case hecate_identity:get_mri() of
                {ok, Mri}       -> Mri;
                not_initialized -> undefined
            end
    end.

safe_list_confirmed() ->
    case ets:whereis(realm_memberships) of
        undefined -> {ok, []};
        _ -> project_realm_memberships_store:list_confirmed()
    end.

resolve_realm(#{realm_id := Realm}) when is_binary(Realm), byte_size(Realm) > 0 ->
    Realm;
resolve_realm(#{realm_url := Url}) when is_binary(Url) ->
    Url;
resolve_realm(_) ->
    undefined.

matches_grantee(<<"mri:realm:", _/binary>>, _OwnMri) -> true;
matches_grantee(OwnMri, OwnMri) when is_binary(OwnMri) -> true;
matches_grantee(_, _) -> false.

extract_data(#{<<"data">> := D}) when is_map(D) -> D;
extract_data(#{data := D}) when is_map(D) -> D;
extract_data(Evt) when is_map(Evt) -> Evt;
extract_data(_) -> #{}.

event_type_of(#{<<"event_type">> := T}) -> T;
event_type_of(#{event_type := T}) -> T;
event_type_of(_) -> undefined.

wrap_strategy_atom(<<"realm_key_v1">>)  -> realm_key_v1;
wrap_strategy_atom(<<"did_x25519_v1">>) -> did_x25519_v1;
wrap_strategy_atom(A) when is_atom(A)   -> A;
wrap_strategy_atom(_)                   -> undefined.

decode_maybe_base64(undefined) -> undefined;
decode_maybe_base64(B) when is_binary(B) ->
    try base64:decode(B)
    catch _:_ -> B
    end;
decode_maybe_base64(Other) -> Other.

normalize_reason(A) when is_atom(A)   -> A;
normalize_reason(B) when is_binary(B) ->
    try binary_to_existing_atom(B, utf8)
    catch _:_ -> revoked
    end;
normalize_reason(_) -> revoked.

gf(K, M) -> gf(K, M, undefined).
gf(K, M, Default) when is_map(M) ->
    case maps:find(K, M) of
        {ok, V} -> V;
        error ->
            case is_atom(K) of
                true  -> maps:get(atom_to_binary(K, utf8), M, Default);
                false -> Default
            end
    end;
gf(_, _, Default) -> Default.
