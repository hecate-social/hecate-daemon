%%% @doc Mesh listener: `{realm}.licenses.issued_batch` → dispatch
%%% `accept_license_v1` for every entry matching this daemon's MRI.
%%%
%%% Phase D live-delivery path. Catch-up (reconnect-after-offline)
%%% lands in Session 3 as a sibling worker.
%%%
%%% Guarded against boot-order: subscribes only once `hecate_mesh_client`
%%% is registered and mesh is activated. Retries every 10s otherwise.
%%% @end
-module(listen_for_license_batch).
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
handle_info({mesh_license_batch, Msg}, State) ->
    handle_batch_message(Msg, State),
    {noreply, State};
handle_info(_, State) ->
    {noreply, State}.

terminate(_Reason, #state{sub_ref = undefined}) -> ok;
terminate(_Reason, #state{sub_ref = Ref}) ->
    _ = catch hecate_mesh:unsubscribe(Ref),
    ok.

code_change(_, State, _) -> {ok, State}.

%% --- Internal ---

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
    Topic = hecate_topics:org_fact(<<"licenses">>, <<"issued_batch">>, 1),
    Self = self(),
    Callback = fun(Msg) -> Self ! {mesh_license_batch, Msg} end,
    case hecate_mesh:subscribe(Topic, Callback) of
        {ok, Ref} ->
            logger:info("[listen_for_license_batch] subscribed topic=~s mri=~s",
                        [Topic, Mri]),
            {noreply, State#state{sub_ref = Ref, topic = Topic, own_mri = Mri}};
        {error, Reason} ->
            logger:warning("[listen_for_license_batch] subscribe failed: ~p",
                           [Reason]),
            schedule_retry(),
            {noreply, State}
    end.

schedule_retry() ->
    erlang:send_after(?RETRY_MS, self(), try_subscribe).

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

dispatch_matching(Payload, #state{own_mri = OwnMri}) ->
    Realm     = gf(realm, Payload),
    BatchId   = gf(batch_id, Payload),
    IssuerDid = gf(issuer_did, Payload),
    Entries   = gf(entries, Payload, []),
    OwnEntries = [E || E <- Entries, matches_grantee(gf(grantee, E), OwnMri)],
    lists:foreach(
        fun(Entry) -> dispatch_accept(Entry, Realm, IssuerDid, BatchId) end,
        OwnEntries).

%% A realm-scope grantee is "mri:realm:{Realm}" — every realm member
%% matches. DID-scope grantee matches own MRI exactly.
matches_grantee(<<"mri:realm:", _/binary>>, _OwnMri) -> true;
matches_grantee(OwnMri, OwnMri) when is_binary(OwnMri) -> true;
matches_grantee(_, _) -> false.

dispatch_accept(Entry, Realm, IssuerDid, BatchId) ->
    Payload = #{
        license_id      => gf(license_id, Entry),
        file_id         => gf(file_id,    Entry),
        grantee         => gf(grantee,    Entry),
        wrap_strategy   => wrap_strategy_atom(gf(wrap_strategy, Entry)),
        wrapped_cek     => decode_wrapped_cek(gf(wrapped_cek, Entry)),
        k_realm_version => gf(k_realm_version, Entry),
        issuer_did      => IssuerDid,
        realm           => Realm,
        issued_at       => gf(issued_at, Entry),
        expires_at      => gf(expires_at, Entry)},
    case validate_entry(Payload) of
        ok ->
            do_dispatch(Payload, BatchId);
        {error, Reason} ->
            logger:warning("[listen_for_license_batch] skip batch=~s: ~p",
                           [BatchId, Reason])
    end.

validate_entry(P) ->
    Required = [license_id, file_id, grantee, wrap_strategy,
                wrapped_cek, issuer_did, realm,
                issued_at, expires_at],
    lists:foldl(
        fun(_K, {error, _} = Err) -> Err;
           (K, ok) ->
               case maps:get(K, P, undefined) of
                   undefined -> {error, {missing, K}};
                   _ -> ok
               end
        end, ok, Required).

do_dispatch(Payload, BatchId) ->
    case accept_license_v1:new(Payload) of
        {ok, Cmd} ->
            log_result(BatchId, maps:get(license_id, Payload),
                       maybe_accept_license:dispatch(Cmd));
        {error, Reason} ->
            logger:warning("[listen_for_license_batch] cmd build failed: ~p",
                           [Reason])
    end.

log_result(BatchId, LicenseId, {ok, _V, _Events}) ->
    logger:info("[listen_for_license_batch] accepted batch=~s license=~s",
                [BatchId, LicenseId]);
log_result(BatchId, LicenseId, {error, already_accepted}) ->
    logger:debug("[listen_for_license_batch] idempotent batch=~s license=~s",
                 [BatchId, LicenseId]);
log_result(BatchId, LicenseId, {error, Reason}) ->
    logger:info("[listen_for_license_batch] dispatch error batch=~s license=~s: ~p",
                [BatchId, LicenseId, Reason]).

wrap_strategy_atom(<<"realm_key_v1">>)  -> realm_key_v1;
wrap_strategy_atom(<<"did_x25519_v1">>) -> did_x25519_v1;
wrap_strategy_atom(A) when is_atom(A)   -> A;
wrap_strategy_atom(_)                   -> undefined.

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
