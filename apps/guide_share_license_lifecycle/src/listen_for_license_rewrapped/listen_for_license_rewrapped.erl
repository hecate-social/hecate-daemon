%%% @doc Mesh listener: `{realm}.licenses.rewrapped_batch` -> dispatch
%%% `receive_license_rewrap_v1` for every entry matching a license this
%%% daemon has accepted.
%%%
%%% Live-delivery of issuer rewraps post K_realm rotation. Missed
%%% rewraps (while offline) are handled by `catch_up_realm_licenses`.
%%%
%%% Same boot-order safety pattern as `listen_for_license_batch`:
%%% retries every 10s until `hecate_mesh_client` is registered and the
%%% mesh is activated.
%%% @end
-module(listen_for_license_rewrapped).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).
-define(RETRY_MS, 10000).

-record(state, {
    sub_ref   :: reference() | undefined,
    topic     :: binary() | undefined,
    own_mri   :: binary() | undefined
}).

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init([]) ->
    self() ! try_subscribe,
    {ok, #state{}}.

handle_call(_, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_, State) ->
    {noreply, State}.

handle_info(try_subscribe, State) ->
    handle_subscribe_attempt(State);
handle_info({mesh_rewrapped_batch, Msg}, State) ->
    handle_batch_message(Msg, State),
    {noreply, State};
handle_info(_, State) ->
    {noreply, State}.

terminate(_Reason, #state{sub_ref = undefined}) -> ok;
terminate(_Reason, #state{sub_ref = Ref}) ->
    _ = catch hecate_mesh:unsubscribe(Ref),
    ok.

code_change(_, State, _) -> {ok, State}.

%%====================================================================
%% Subscribe
%%====================================================================

handle_subscribe_attempt(State) ->
    case {erlang:whereis(hecate_mesh_client), hecate_identity_available()} of
        {undefined, _} ->
            schedule_retry(),
            {noreply, State};
        {_Pid, {ok, Mri}} ->
            subscribe_now(Mri, State);
        {_Pid, not_ready} ->
            schedule_retry(),
            {noreply, State}
    end.

hecate_identity_available() ->
    case erlang:whereis(hecate_identity) of
        undefined -> not_ready;
        _ ->
            case hecate_identity:get_mri() of
                {ok, Mri}       -> {ok, Mri};
                not_initialized -> not_ready
            end
    end.

subscribe_now(Mri, State) ->
    Topic = hecate_topics:org_fact(<<"licenses">>, <<"rewrapped_batch">>, 1),
    Self = self(),
    Callback = fun(Msg) -> Self ! {mesh_rewrapped_batch, Msg} end,
    case hecate_mesh:subscribe(Topic, Callback) of
        {ok, Ref} ->
            logger:info("[listen_for_license_rewrapped] subscribed topic=~s mri=~s",
                        [Topic, Mri]),
            {noreply, State#state{sub_ref = Ref, topic = Topic, own_mri = Mri}};
        {error, Reason} ->
            logger:warning("[listen_for_license_rewrapped] subscribe failed: ~p",
                           [Reason]),
            schedule_retry(),
            {noreply, State}
    end.

schedule_retry() ->
    erlang:send_after(?RETRY_MS, self(), try_subscribe).

%%====================================================================
%% Dispatch
%%====================================================================

handle_batch_message(Msg, State) ->
    Payload = extract_payload(Msg),
    dispatch_matching(Payload, State).

extract_payload(#{payload := P}) when is_map(P) -> P;
extract_payload(#{payload := P}) when is_binary(P) -> decode_json(P);
extract_payload(P) when is_map(P) -> P;
extract_payload(P) when is_binary(P) -> decode_json(P);
extract_payload(_) -> #{}.

decode_json(Bin) ->
    try json:decode(Bin) of
        Map when is_map(Map) -> Map;
        _ -> #{}
    catch _:_ -> #{}
    end.

dispatch_matching(Payload, _State) ->
    BatchId    = gf(batch_id, Payload),
    NewVersion = gf(new_k_realm_version, Payload),
    Entries    = gf(entries, Payload, []),
    lists:foreach(
        fun(Entry) -> dispatch_entry(Entry, NewVersion, BatchId) end,
        Entries).

%% Recipient filter: we try to dispatch for every entry — the aggregate
%% guards reject licenses we never accepted with `{error, unknown_command}`
%% at the `status = 0` clause (since `receive_license_rewrap_v1` is only
%% valid on SL_ACCEPTED state). No preliminary ETS lookup needed; the
%% aggregate is the source of truth.
dispatch_entry(Entry, NewVersion, BatchId) ->
    LicenseId = gf(license_id, Entry),
    NewWrappedCek = decode_wrapped_cek(gf(new_wrapped_cek, Entry)),
    RewrappedAt = gf(rewrapped_at, Entry),
    case LicenseId of
        undefined ->
            logger:warning("[listen_for_license_rewrapped] missing license_id in batch=~s",
                           [BatchId]);
        _ ->
            do_dispatch(LicenseId, NewWrappedCek, NewVersion, BatchId, RewrappedAt)
    end.

do_dispatch(LicenseId, NewWrappedCek, NewVersion, BatchId, RewrappedAt) ->
    case receive_license_rewrap_v1:new(#{
            license_id          => LicenseId,
            new_wrapped_cek     => NewWrappedCek,
            new_k_realm_version => NewVersion,
            batch_id            => BatchId,
            rewrapped_at        => RewrappedAt}) of
        {ok, Cmd} ->
            log_result(BatchId, LicenseId,
                       maybe_receive_license_rewrap:dispatch(Cmd));
        {error, Reason} ->
            logger:warning("[listen_for_license_rewrapped] cmd build failed batch=~s license=~s: ~p",
                           [BatchId, LicenseId, Reason])
    end.

log_result(BatchId, LicenseId, {ok, _V, _Events}) ->
    logger:info("[listen_for_license_rewrapped] applied batch=~s license=~s",
                [BatchId, LicenseId]);
log_result(BatchId, LicenseId, {error, license_not_accepted}) ->
    %% Expected: we never accepted this license (not our grantee, or
    %% issuer sent us the batch for a different reason).
    logger:debug("[listen_for_license_rewrapped] skip unaccepted batch=~s license=~s",
                 [BatchId, LicenseId]);
log_result(BatchId, LicenseId, {error, license_ended}) ->
    logger:debug("[listen_for_license_rewrapped] skip ended batch=~s license=~s",
                 [BatchId, LicenseId]);
log_result(BatchId, LicenseId, {error, stale_rewrap}) ->
    logger:debug("[listen_for_license_rewrapped] idempotent batch=~s license=~s",
                 [BatchId, LicenseId]);
log_result(BatchId, LicenseId, {error, Reason}) ->
    logger:info("[listen_for_license_rewrapped] dispatch error batch=~s license=~s: ~p",
                [BatchId, LicenseId, Reason]).

%%====================================================================
%% Helpers
%%====================================================================

decode_wrapped_cek(B) when is_binary(B) ->
    try base64:decode(B)
    catch _:_ -> B
    end;
decode_wrapped_cek(Other) -> Other.

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
