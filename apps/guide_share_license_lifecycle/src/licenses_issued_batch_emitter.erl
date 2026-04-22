%%% @doc Buffered emitter: license_issued_v1 events → one batch FACT
%%% per share on `{realm}.licenses.issued_batch`.
%%%
%%% Batching is a transport optimisation: a single share to N recipients
%%% generates N issue_license commands each emitting their own
%%% `license_issued_v1`. Publishing N mesh events per share bloats the
%%% wire and the realm registry. Instead this gen_server buffers by
%%% `batch_id` and flushes after 500ms of quiescence or when the buffer
%%% hits `?MAX_ENTRIES_PER_BATCH`.
%%%
%%% Receives buffered events via cast from
%%% `license_issued_v1_to_batch`, the evoq_event_handler sibling
%%% module that subscribes on `share_licenses_store`.
%%%
%%% Shape of the mesh FACT (`licenses_issued_batch_v1`):
%%% ```
%%% #{event_type => <<"licenses_issued_batch_v1">>,
%%%   realm      => Realm,
%%%   batch_id   => BatchId,
%%%   issuer_did => IssuerDid,
%%%   entries    => [#{license_id, grantee, file_id,
%%%                    wrap_strategy, wrapped_cek,
%%%                    k_realm_version, issued_at, expires_at}, ...]}
%%% ```
%%%
%%% Wrapped CEKs are base64-encoded for JSON-safe transport.
%%% @end
-module(licenses_issued_batch_emitter).
-behaviour(gen_server).

-export([start_link/0, buffer/1, flush/1, pending/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(FLUSH_QUIESCENCE_MS, 500).
-define(MAX_ENTRIES_PER_BATCH, 50).
-define(SERVER, ?MODULE).

%% --- API ---

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec buffer(map()) -> ok.
buffer(Data) when is_map(Data) ->
    gen_server:cast(?SERVER, {buffer, Data}).

%% @doc Force immediate flush of a batch_id (test hook).
-spec flush(binary()) -> ok.
flush(BatchId) when is_binary(BatchId) ->
    gen_server:cast(?SERVER, {flush, BatchId}).

%% @doc Count of buffered batches (test hook).
-spec pending() -> non_neg_integer().
pending() ->
    gen_server:call(?SERVER, pending).

%% --- gen_server callbacks ---

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

%% --- Internal ---

do_buffer(Data, #{batches := B, timers := T} = State) ->
    case gf(batch_id, Data) of
        undefined ->
            logger:warning("[licenses_batch_emit] event missing batch_id: ~p", [Data]),
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
    Realm = first_field(realm, Reversed),
    Issuer = first_field(issuer_did, Reversed),
    do_publish_or_drop(BatchId, Realm, Issuer, Reversed).

do_publish_or_drop(BatchId, undefined, _Issuer, _Entries) ->
    logger:warning("[licenses_batch_emit] batch=~s missing realm; dropping",
                   [BatchId]);
do_publish_or_drop(BatchId, _Realm, undefined, _Entries) ->
    logger:warning("[licenses_batch_emit] batch=~s missing issuer_did; dropping",
                   [BatchId]);
do_publish_or_drop(BatchId, Realm, Issuer, Entries) ->
    Topic = hecate_topics:fact(<<"licenses">>, <<"issued_batch">>, 1),
    Fact = #{
        event_type => <<"licenses_issued_batch_v1">>,
        realm      => Realm,
        batch_id   => BatchId,
        issuer_did => Issuer,
        entries    => [to_batch_entry(E) || E <- Entries]},
    log_publish(BatchId, Realm, length(Entries),
                hecate_mesh:publish(Topic, Fact)).

log_publish(BatchId, Realm, Count, ok) ->
    logger:info("[licenses_batch_emit] batch=~s entries=~b realm=~s",
                [BatchId, Count, Realm]);
log_publish(BatchId, _Realm, _Count, {error, Reason}) ->
    logger:warning("[licenses_batch_emit] publish failed batch=~s: ~p",
                   [BatchId, Reason]).

to_batch_entry(E) ->
    #{license_id      => gf(license_id, E),
      grantee         => gf(grantee, E),
      file_id         => gf(file_id, E),
      wrap_strategy   => atom_to_binary(
                             to_atom(gf(wrap_strategy, E)), utf8),
      wrapped_cek     => base64:encode(gf(wrapped_cek, E, <<>>)),
      k_realm_version => gf(k_realm_version, E),
      issued_at       => gf(issued_at, E),
      expires_at      => gf(expires_at, E)}.

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

first_field(_K, [])          -> undefined;
first_field(K, [Entry | Rest]) ->
    case gf(K, Entry) of
        undefined -> first_field(K, Rest);
        V         -> V
    end.

to_atom(A) when is_atom(A)   -> A;
to_atom(B) when is_binary(B) -> binary_to_atom(B, utf8);
to_atom(undefined)           -> undefined.
