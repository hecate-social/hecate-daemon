%%% @doc Buffered emitter: `license_rewrapped_v1` events -> one batch
%%% FACT per rotation on `{realm}.licenses.rewrapped_batch`.
%%%
%%% Mirror of `licenses_issued_batch_emitter` for the rewrap path.
%%% On K_realm rotation the rewrap PM dispatches N `rewrap_license_v1`
%%% commands (one per realm-scope license this daemon issued under the
%%% old version), each producing a `license_rewrapped_v1` event. Those
%%% are relayed here by `license_rewrapped_v1_to_batch` and coalesced
%%% into a single mesh FACT so recipients see one batch instead of
%%% N individual messages.
%%%
%%% Batch coalescing key is `batch_id` — the PM stamps all rewraps for
%%% a single rotation with the same id. Flush triggers: 500 ms of
%%% quiescence OR `?MAX_ENTRIES_PER_BATCH` reached.
%%%
%%% Shape of the mesh FACT (`licenses_rewrapped_batch_v1`):
%%% ```
%%% #{event_type => <<"licenses_rewrapped_batch_v1">>,
%%%   realm      => Realm,
%%%   batch_id   => BatchId,
%%%   issuer_did => IssuerDid,
%%%   new_k_realm_version => V,
%%%   entries    => [#{license_id, grantee, new_wrapped_cek,
%%%                    rewrapped_at}, ...]}
%%% ```
%%%
%%% Wrapped CEKs are base64-encoded for JSON-safe transport (same as
%%% the issued batch).
%%% @end
-module(licenses_rewrapped_batch_emitter).
-behaviour(gen_server).

-export([start_link/0, buffer/1, flush/1, pending/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(FLUSH_QUIESCENCE_MS, 500).
-define(MAX_ENTRIES_PER_BATCH, 50).
-define(SERVER, ?MODULE).

%%====================================================================
%% API
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec buffer(map()) -> ok.
buffer(Data) when is_map(Data) ->
    gen_server:cast(?SERVER, {buffer, Data}).

-spec flush(binary()) -> ok.
flush(BatchId) when is_binary(BatchId) ->
    gen_server:cast(?SERVER, {flush, BatchId}).

-spec pending() -> non_neg_integer().
pending() ->
    gen_server:call(?SERVER, pending).

%%====================================================================
%% gen_server
%%====================================================================

init([]) ->
    {ok, #{batches => #{}, timers => #{}}}.

handle_call(pending, _From, #{batches := B} = State) ->
    {reply, map_size(B), State};
handle_call(_, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast({buffer, Data}, State) ->
    {noreply, do_buffer(Data, State)};
handle_cast({flush, BatchId}, State) ->
    {noreply, do_flush_one(BatchId, State)};
handle_cast(_, State) ->
    {noreply, State}.

handle_info({flush_timer, BatchId}, State) ->
    {noreply, do_flush_one(BatchId, State)};
handle_info(_, State) ->
    {noreply, State}.

terminate(_Reason, _State) -> ok.
code_change(_, State, _)   -> {ok, State}.

%%====================================================================
%% Internal
%%====================================================================

do_buffer(Data, #{batches := B, timers := T} = State) ->
    case gf(batch_id, Data) of
        undefined ->
            logger:warning("[licenses_rewrapped_batch] event missing batch_id: ~p", [Data]),
            State;
        BatchId ->
            Entries = maps:get(BatchId, B, []),
            NewEntries = [Data | Entries],
            B1 = B#{BatchId => NewEntries},
            maybe_flush_or_rearm(BatchId, NewEntries, B1, T, State)
    end.

maybe_flush_or_rearm(BatchId, Entries, B1, T, State)
  when length(Entries) >= ?MAX_ENTRIES_PER_BATCH ->
    cancel_timer(BatchId, T),
    publish_batch(BatchId, Entries),
    State#{batches => maps:remove(BatchId, B1),
           timers  => maps:remove(BatchId, T)};
maybe_flush_or_rearm(BatchId, _Entries, B1, T, State) ->
    T1 = restart_timer(BatchId, T),
    State#{batches => B1, timers => T1}.

do_flush_one(BatchId, #{batches := B, timers := T} = State) ->
    case maps:find(BatchId, B) of
        {ok, Entries} ->
            cancel_timer(BatchId, T),
            publish_batch(BatchId, Entries),
            State#{batches => maps:remove(BatchId, B),
                   timers  => maps:remove(BatchId, T)};
        error ->
            State
    end.

restart_timer(BatchId, Timers) ->
    cancel_timer(BatchId, Timers),
    TRef = erlang:send_after(?FLUSH_QUIESCENCE_MS, self(),
                             {flush_timer, BatchId}),
    Timers#{BatchId => TRef}.

cancel_timer(BatchId, Timers) ->
    case maps:find(BatchId, Timers) of
        {ok, TRef} -> _ = erlang:cancel_timer(TRef), ok;
        error      -> ok
    end.

publish_batch(BatchId, Entries) ->
    Reversed = lists:reverse(Entries),
    Realm   = first_field(realm, Reversed),
    Issuer  = first_field(issuer_did, Reversed),
    NewVer  = first_field(new_k_realm_version, Reversed),
    do_publish_or_drop(BatchId, Realm, Issuer, NewVer, Reversed).

do_publish_or_drop(BatchId, undefined, _Issuer, _V, _Entries) ->
    logger:warning("[licenses_rewrapped_batch] batch=~s missing realm; dropping",
                   [BatchId]);
do_publish_or_drop(BatchId, _Realm, undefined, _V, _Entries) ->
    logger:warning("[licenses_rewrapped_batch] batch=~s missing issuer_did; dropping",
                   [BatchId]);
do_publish_or_drop(BatchId, _Realm, _Issuer, undefined, _Entries) ->
    logger:warning("[licenses_rewrapped_batch] batch=~s missing new_k_realm_version; dropping",
                   [BatchId]);
do_publish_or_drop(BatchId, Realm, Issuer, NewVer, Entries) ->
    Topic = hecate_topics:org_fact(<<"licenses">>, <<"rewrapped_batch">>, 1),
    Fact = #{
        event_type          => <<"licenses_rewrapped_batch_v1">>,
        realm               => Realm,
        batch_id            => BatchId,
        issuer_did          => Issuer,
        new_k_realm_version => NewVer,
        entries             => [to_batch_entry(E) || E <- Entries]},
    log_publish(BatchId, Realm, length(Entries),
                hecate_mesh:publish(Topic, Fact)).

log_publish(BatchId, Realm, Count, ok) ->
    logger:info("[licenses_rewrapped_batch] batch=~s entries=~b realm=~s",
                [BatchId, Count, Realm]);
log_publish(BatchId, _Realm, _Count, {error, Reason}) ->
    logger:warning("[licenses_rewrapped_batch] publish failed batch=~s: ~p",
                   [BatchId, Reason]).

to_batch_entry(E) ->
    #{license_id      => gf(license_id, E),
      grantee         => gf(grantee, E),
      new_wrapped_cek => base64:encode(gf(new_wrapped_cek, E, <<>>)),
      rewrapped_at    => gf(rewrapped_at, E)}.

gf(K, M) -> gf(K, M, undefined).
gf(K, M, Default) ->
    case maps:find(K, M) of
        {ok, V} -> V;
        error   ->
            case is_atom(K) of
                true  -> maps:get(atom_to_binary(K, utf8), M, Default);
                false -> Default
            end
    end.

first_field(_K, [])              -> undefined;
first_field(K, [Entry | Rest])   ->
    case gf(K, Entry) of
        undefined -> first_field(K, Rest);
        V         -> V
    end.
