%%% @doc Boot-time + periodic catch-up for `K_realm` across memberships.
%%%
%%% Covers two gaps the confirm-driven PM alone can't:
%%%
%%%   1. **Historical memberships.** A membership confirmed before the
%%%      PM existed has no `K_realm` stored. On boot this worker scans
%%%      confirmed-not-revoked memberships and fetches.
%%%   2. **Missed rotations.** If the daemon was offline during a
%%%      rotation on the realm server, the local version lags. The
%%%      mesh RPC returns the current version; if it's newer than
%%%      what the aggregate already knows, the dispatched store
%%%      command lands a new `realm_shared_key_stored_v1`.
%%%
%%% Driver: gen_server that:
%%%
%%%   - waits for `hecate_mesh:is_activated/0` to flip true (poll each
%%%     few seconds until ready),
%%%   - runs one scan,
%%%   - then repeats the scan every `?SCAN_INTERVAL_MS`.
%%%
%%% Failures are logged and don't stop the scan — a missing RPC on
%%% one realm does not affect the others.
%%% @end
-module(catch_up_realm_keys).
-behaviour(gen_server).

-include_lib("guide_realm_memberships/include/membership_status.hrl").

-export([start_link/0, scan_now/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% ~5 minutes between sweeps — long enough to not spam the mesh
%% server, short enough that a missed rotation heals quickly.
-define(SCAN_INTERVAL_MS,     5 * 60 * 1000).
%% Poll interval while waiting for mesh activation at boot.
-define(ACTIVATION_POLL_MS,   3 * 1000).

-record(state, {
    timer_ref :: reference() | undefined
}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Trigger an immediate scan. Mostly for tests + operator nudges.
-spec scan_now() -> ok.
scan_now() ->
    gen_server:cast(?MODULE, scan_now).

%%====================================================================
%% gen_server
%%====================================================================

init([]) ->
    self() ! check_activation,
    {ok, #state{}}.

handle_call(_Msg, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(scan_now, State) ->
    scan_memberships(),
    {noreply, State}.

handle_info(check_activation, State) ->
    handle_activation(hecate_mesh:is_activated(), State);

handle_info(periodic_scan, State) ->
    scan_memberships(),
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
    logger:info("[catch_up.realm_keys] mesh activated, running initial scan"),
    scan_memberships(),
    {noreply, State#state{timer_ref = schedule_next()}};
handle_activation(false, State) ->
    erlang:send_after(?ACTIVATION_POLL_MS, self(), check_activation),
    {noreply, State}.

schedule_next() ->
    erlang:send_after(?SCAN_INTERVAL_MS, self(), periodic_scan).

scan_memberships() ->
    case safe_list_confirmed() of
        {ok, Memberships} ->
            scan_each(Memberships);
        {error, Reason} ->
            logger:warning("[catch_up.realm_keys] list_confirmed failed: ~p",
                           [Reason])
    end.

safe_list_confirmed() ->
    case ets:whereis(realm_memberships) of
        undefined -> {ok, []};
        _ -> project_realm_memberships_store:list_confirmed()
    end.

scan_each([]) ->
    ok;
scan_each([Membership | Rest]) ->
    maybe_fetch(Membership),
    scan_each(Rest).

maybe_fetch(#{status := Status} = Membership) ->
    Revoked = evoq_bit_flags:has(Status, ?MEMBERSHIP_REVOKED),
    Confirmed = evoq_bit_flags:has(Status, ?MEMBERSHIP_CONFIRMED),
    case {Confirmed, Revoked} of
        {true, false} -> fetch_for(Membership);
        _             -> ok
    end;
maybe_fetch(_) ->
    ok.

fetch_for(#{membership_id := MId} = M) ->
    Realm = resolve_realm(M),
    log_result(Realm, realm_key_fetcher:fetch_and_store(MId, Realm));
fetch_for(_) ->
    ok.

resolve_realm(#{realm_id := Realm}) when is_binary(Realm), byte_size(Realm) > 0 ->
    Realm;
resolve_realm(#{realm_url := Url}) when is_binary(Url) ->
    Url;
resolve_realm(_) ->
    undefined.

log_result(_Realm, {ok, Version}) ->
    logger:info("[catch_up.realm_keys] K_realm v~p fresh", [Version]);
log_result(Realm, {error, {no_realm_key, _}}) ->
    logger:info("[catch_up.realm_keys] realm ~s has no key yet", [Realm]);
log_result(Realm, {error, Reason}) ->
    logger:info("[catch_up.realm_keys] ~s skipped: ~p", [Realm, Reason]).
