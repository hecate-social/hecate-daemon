%%% @doc watch_mri desk: push-subscription registry + change-driven
%%% delivery. PLAN_RESOLVE_MESH_NAMES_PART1 §3.2.
%%%
%%% A caller does `watch(Pool, Mri, self())' and receives, in its
%%% mailbox, messages whenever the MRI's resolution changes:
%%%   `{resolve_mesh_names, SubHandle, record_changed,    VerifiedRecord}'
%%%   `{resolve_mesh_names, SubHandle, record_tombstoned, Mri}'
%%%   `{resolve_mesh_names, SubHandle, trust_chain_lost,  Mri, Reason}'
%%%
%%% On subscribe, if `watch_delivers_current_value' app env is
%%% true (the default), the current resolution is delivered
%%% immediately (a `record_changed' carrying the present value, or
%%% `trust_chain_lost' / `record_tombstoned' if it doesn't resolve).
%%%
%%% Change stream: the two invalidation PMs
%%% (`on_record_observed_invalidate_cache' /
%%% `on_realm_directory_changed_warm_cache') call
%%% `watch_mri:realm_changed/2' right after they invalidate a
%%% realm's cache subtree. For each watcher whose MRI lives in that
%%% realm, watch_mri re-resolves (using the Pool the watcher
%%% supplied) and delivers the appropriate message. Station MRIs
%%% (self-rooted, no realm) aren't matched by realm_changed yet —
%%% change-driven delivery for station MRIs is a follow-up; their
%%% watchers still get the current-value-on-subscribe.
%%%
%%% Subscriber liveness: each watch monitors the caller pid; on
%%% DOWN the subscription is auto-removed (no need to unwatch from
%%% a crashed process).
%%%
%%% Owns the named ETS table `resolve_mesh_names_watch_subs',
%%% keyed by SubHandle (a `reference()'), value
%%% `{Pid, MonRef, Mri, RealmOrUndefined, Pool}'. Reads are
%%% concurrent; writes serialise through this gen_server.
%%% @end
-module(watch_mri).
-behaviour(gen_server).

-export([start_link/0, watch/3, unwatch/1, realm_changed/2,
         active_count/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SUBS_TABLE, resolve_mesh_names_watch_subs).

%%====================================================================
%% Public API
%%====================================================================

%% @doc Subscribe to changes for an MRI. Returns a `SubHandle' the
%% caller passes to `unwatch/1' later. The caller's mailbox
%% receives the message shapes documented in the module header.
-spec watch(Pool :: pid(), Mri :: binary(), Pid :: pid()) ->
    {ok, reference()} | {error, atom()}.
watch(Pool, Mri, Pid) when is_binary(Mri), is_pid(Pid) ->
    gen_server:call(?MODULE, {watch, Pool, Mri, Pid});
watch(_, _, _) ->
    {error, bad_args}.

%% @doc Cancel a subscription. Idempotent — a stale or unknown
%% handle is a no-op.
-spec unwatch(SubHandle :: reference()) -> ok.
unwatch(SubHandle) when is_reference(SubHandle) ->
    gen_server:call(?MODULE, {unwatch, SubHandle});
unwatch(_) ->
    ok.

%% @doc Called by the invalidation PMs after they invalidate a
%% realm's cache subtree. `Kind' is `changed' (version bump) or
%% `tombstoned' (revocation). watch_mri re-resolves each watched
%% MRI in that realm and delivers the appropriate message.
-spec realm_changed(RealmId :: binary(), Kind :: changed | tombstoned) -> ok.
realm_changed(RealmId, Kind) when is_binary(RealmId),
                                  (Kind =:= changed orelse Kind =:= tombstoned) ->
    gen_server:cast(?MODULE, {realm_changed, RealmId, Kind});
realm_changed(_, _) ->
    ok.

%% @doc Diagnostic: number of active subscriptions.
-spec active_count() -> non_neg_integer().
active_count() ->
    case ets:info(?SUBS_TABLE, size) of
        undefined -> 0;
        N         -> N
    end.

%%====================================================================
%% gen_server callbacks
%%====================================================================

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    catch ets:delete(?SUBS_TABLE),
    ?SUBS_TABLE = ets:new(?SUBS_TABLE, [named_table, protected, set,
                                        {read_concurrency, true}]),
    {ok, #{}}.

handle_call({watch, Pool, Mri, Pid}, _From, State) ->
    SubHandle = make_ref(),
    MonRef    = erlang:monitor(process, Pid),
    Realm     = realm_of(Mri),
    ets:insert(?SUBS_TABLE, {SubHandle, {Pid, MonRef, Mri, Realm, Pool}}),
    maybe_deliver_current(SubHandle, Pid, Mri, Pool),
    {reply, {ok, SubHandle}, State};
handle_call({unwatch, SubHandle}, _From, State) ->
    drop_sub(SubHandle),
    {reply, ok, State};
handle_call(_Req, _From, S) ->
    {reply, {error, not_yet_implemented}, S}.

handle_cast({realm_changed, RealmId, Kind}, State) ->
    deliver_realm_change(RealmId, Kind),
    {noreply, State};
handle_cast(_Msg, S) ->
    {noreply, S}.

handle_info({'DOWN', MonRef, process, _Pid, _Reason}, State) ->
    drop_sub_by_monref(MonRef),
    {noreply, State};
handle_info(_Info, S) ->
    {noreply, S}.

terminate(_Reason, _S) -> ok.
code_change(_Old, S, _Ex) -> {ok, S}.

%%====================================================================
%% Subscription bookkeeping
%%====================================================================

drop_sub(SubHandle) ->
    case ets:lookup(?SUBS_TABLE, SubHandle) of
        [{_, {_Pid, MonRef, _Mri, _Realm, _Pool}}] ->
            erlang:demonitor(MonRef, [flush]),
            ets:delete(?SUBS_TABLE, SubHandle);
        [] ->
            ok
    end.

drop_sub_by_monref(MonRef) ->
    %% O(N) scan to find the sub with this monitor; N = active subs.
    ets:foldl(fun
        ({SubHandle, {_Pid, MR, _Mri, _Realm, _Pool}}, _Acc) when MR =:= MonRef ->
            ets:delete(?SUBS_TABLE, SubHandle),
            ok;
        (_, Acc) -> Acc
    end, ok, ?SUBS_TABLE),
    ok.

%%====================================================================
%% Delivery
%%====================================================================

maybe_deliver_current(SubHandle, Pid, Mri, Pool) ->
    case deliver_current_value_enabled() of
        true  -> resolve_and_deliver(SubHandle, Pid, Mri, Pool, changed);
        false -> ok
    end.

deliver_current_value_enabled() ->
    application:get_env(resolve_mesh_names, watch_delivers_current_value, true).

deliver_realm_change(RealmId, Kind) ->
    Watchers = ets:foldl(fun
        ({SubHandle, {Pid, _MR, Mri, Realm, Pool}}, Acc) when Realm =:= RealmId ->
            [{SubHandle, Pid, Mri, Pool} | Acc];
        (_, Acc) -> Acc
    end, [], ?SUBS_TABLE),
    [resolve_and_deliver(SubHandle, Pid, Mri, Pool, Kind)
     || {SubHandle, Pid, Mri, Pool} <- Watchers],
    ok.

%% Re-resolve and send the right message shape.
resolve_and_deliver(SubHandle, Pid, Mri, Pool, Kind) ->
    case resolve_mri:resolve(Pool, Mri, #{}) of
        {ok, [VR | _]} ->
            Pid ! {resolve_mesh_names, SubHandle, record_changed, VR},
            ok;
        {ok, []} ->
            %% Resolved to "nothing exists" — treat like a tombstone.
            Pid ! {resolve_mesh_names, SubHandle, record_tombstoned, Mri},
            ok;
        {error, name_revoked} ->
            Pid ! {resolve_mesh_names, SubHandle, record_tombstoned, Mri},
            ok;
        {error, _Reason} when Kind =:= tombstoned ->
            %% The change that triggered us was a tombstone, and
            %% re-resolution now fails — deliver as tombstoned.
            Pid ! {resolve_mesh_names, SubHandle, record_tombstoned, Mri},
            ok;
        {error, Reason} ->
            Pid ! {resolve_mesh_names, SubHandle, trust_chain_lost, Mri, Reason},
            ok
    end.

%%====================================================================
%% Helpers
%%====================================================================

%% The realm a watcher's MRI belongs to (for matching realm_changed
%% events). Station MRIs are self-rooted → `undefined' (won't be
%% matched by realm-scoped change events; current-value-on-subscribe
%% still works).
realm_of(<<"mri:station:", _/binary>>) ->
    undefined;
realm_of(Mri) when is_binary(Mri) ->
    case macula_mri:parse(Mri) of
        {ok, #{realm := Realm}} -> Realm;
        _                       -> undefined
    end;
realm_of(_) ->
    undefined.
