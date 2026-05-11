%%% @doc CT suite for the watch_mri desk. PLAN PART1 §3.2.
%%%
%%% Coverage:
%%%   - watch/3 registers; current value delivered on subscribe
%%%     (record_changed) when watch_delivers_current_value is on
%%%   - watch/3 with current-value off → no immediate message
%%%   - unwatch/1 deregisters; idempotent on stale handle
%%%   - subscriber DOWN → auto-unwatch (active_count drops)
%%%   - realm_changed(changed) → watcher of an MRI in that realm
%%%     gets a fresh record_changed
%%%   - realm_changed(tombstoned) + resolve now fails → watcher
%%%     gets record_tombstoned
%%%   - realm_changed for a DIFFERENT realm → watcher untouched
%%%   - station-MRI watcher: gets current-value on subscribe but
%%%     isn't matched by realm_changed (self-rooted, no realm)
%%% @end
-module(watch_mri_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1,
         init_per_testcase/2, end_per_testcase/2]).
-export([
    watch_delivers_current_value_on_subscribe/1,
    watch_without_current_value_is_silent_on_subscribe/1,
    unwatch_deregisters/1,
    unwatch_stale_handle_is_noop/1,
    subscriber_down_auto_unwatches/1,
    realm_changed_delivers_record_changed/1,
    realm_changed_tombstoned_when_resolve_fails/1,
    realm_changed_other_realm_is_ignored/1,
    station_watcher_gets_current_value_not_realm_changes/1
]).

all() ->
    [
        watch_delivers_current_value_on_subscribe,
        watch_without_current_value_is_silent_on_subscribe,
        unwatch_deregisters,
        unwatch_stale_handle_is_noop,
        subscriber_down_auto_unwatches,
        realm_changed_delivers_record_changed,
        realm_changed_tombstoned_when_resolve_fails,
        realm_changed_other_realm_is_ignored,
        station_watcher_gets_current_value_not_realm_changes
    ].

init_per_suite(Config) -> Config.
end_per_suite(_Config) -> ok.

init_per_testcase(_TC, Config) ->
    cleanup([trust_anchors, cache_records, cache_invalidate, cache_ttl_sweep,
             lookup_dedup, lookup_via_dht, verify_trust_chain, resolve_mri,
             watch_mri]),
    {ok, _} = trust_anchors:start_link(),
    {ok, _} = cache_records:start_link(),
    {ok, _} = cache_invalidate:start_link(),
    application:set_env(resolve_mesh_names, cache_ttl_sweep_period_ms, 60000),
    {ok, _} = cache_ttl_sweep:start_link(),
    {ok, _} = lookup_dedup:start_link(),
    {ok, _} = lookup_via_dht:start_link(),
    {ok, _} = verify_trust_chain:start_link(),
    {ok, _} = resolve_mri:start_link(),
    %% Default-on current-value delivery, except where a test
    %% explicitly turns it off in init.
    application:set_env(resolve_mesh_names, watch_delivers_current_value, true),
    {ok, _} = watch_mri:start_link(),
    drain(),
    Config.

end_per_testcase(_TC, _Config) ->
    cleanup([watch_mri, resolve_mri, verify_trust_chain, lookup_via_dht,
             lookup_dedup, cache_ttl_sweep, cache_invalidate, cache_records,
             trust_anchors]),
    application:unset_env(resolve_mesh_names, cache_ttl_sweep_period_ms),
    application:unset_env(resolve_mesh_names, watch_delivers_current_value),
    drain(),
    ok.

cleanup(Names) ->
    [case whereis(N) of
         undefined -> ok;
         Pid       -> catch gen_server:stop(Pid, normal, 1000)
     end || N <- Names],
    ok.

drain() -> receive _ -> drain() after 0 -> ok end.

%%====================================================================
%% Helpers
%%====================================================================

%% A self-signed station endpoint + a stub find_fn served via the
%% L4 cache so resolve_mri's re-resolution path finds it without a
%% per-call find_fn (realm_changed re-resolves with #{}).
%%
%% Trick: pre-populate L4 + L5 directly so resolve_mri:resolve(_, Mri, #{})
%% returns from cache. That sidesteps the find_fn-injection issue
%% for the realm_changed delivery path (which calls resolve with #{}).
seed_station_in_cache(StPk) ->
    Z32 = macula_z32:encode(StPk),
    Mri = <<"mri:station:", Z32/binary>>,
    Future = erlang:system_time(millisecond) + 60000,
    VR = #{record_type => station_endpoint, mri => Mri,
           payload => #{}, signer_pubkey => StPk, chain => [],
           expires_at => Future, version => <<1:128>>,
           observed_at => erlang:system_time(millisecond)},
    ok = cache_records:put(l5, Mri, [VR], Future, 1),
    {Mri, VR}.

%% Seed a user MRI's L5 with a verified record so resolve(_, Mri, #{})
%% returns it; then realm_changed deletes L5 (via cache_invalidate)
%% and re-resolves — for the "changed" test we re-seed before
%% calling realm_changed so the re-resolution succeeds. For the
%% "tombstoned" test we don't re-seed, so re-resolution fails.
seed_user_in_cache(RealmId) ->
    {ok, Mri} = macula_mri:new(user, RealmId, [<<"acme">>, <<"alice">>]),
    Future = erlang:system_time(millisecond) + 60000,
    VR = #{record_type => station_endpoint, mri => Mri,
           payload => #{}, signer_pubkey => crypto:strong_rand_bytes(32),
           chain => [], expires_at => Future, version => <<1:128>>,
           observed_at => erlang:system_time(millisecond)},
    ok = cache_records:put(l5, Mri, [VR], Future, 1),
    {Mri, VR}.

%% Receive a watch message for SubHandle within a timeout.
recv_watch(SubHandle, Timeout) ->
    receive
        {resolve_mesh_names, SubHandle, Kind, Payload} -> {Kind, Payload};
        {resolve_mesh_names, SubHandle, Kind, A, B}    -> {Kind, A, B}
    after Timeout ->
        timeout
    end.

no_watch_message(SubHandle, Timeout) ->
    receive
        {resolve_mesh_names, SubHandle, _Kind, _P}      -> got_a_message;
        {resolve_mesh_names, SubHandle, _Kind, _A, _B}  -> got_a_message
    after Timeout ->
        ok
    end.

%%====================================================================
%% watch / unwatch basics
%%====================================================================

watch_delivers_current_value_on_subscribe(_Config) ->
    {Mri, _VR} = seed_user_in_cache(<<"io.macula">>),
    {ok, Sub} = watch_mri:watch(self(), Mri, self()),
    {record_changed, #{record_type := station_endpoint}} =
        recv_watch(Sub, 1000),
    1 = watch_mri:active_count(),
    ok = watch_mri:unwatch(Sub),
    ok.

watch_without_current_value_is_silent_on_subscribe(_Config) ->
    application:set_env(resolve_mesh_names, watch_delivers_current_value, false),
    {Mri, _VR} = seed_user_in_cache(<<"io.macula">>),
    {ok, Sub} = watch_mri:watch(self(), Mri, self()),
    ok = no_watch_message(Sub, 300),
    ok = watch_mri:unwatch(Sub).

unwatch_deregisters(_Config) ->
    {Mri, _} = seed_user_in_cache(<<"io.macula">>),
    {ok, Sub} = watch_mri:watch(self(), Mri, self()),
    1 = watch_mri:active_count(),
    ok = watch_mri:unwatch(Sub),
    0 = watch_mri:active_count(),
    ok.

unwatch_stale_handle_is_noop(_Config) ->
    ok = watch_mri:unwatch(make_ref()),
    ok = watch_mri:unwatch(not_a_ref),
    0 = watch_mri:active_count(),
    ok.

subscriber_down_auto_unwatches(_Config) ->
    {Mri, _} = seed_user_in_cache(<<"io.macula">>),
    Parent = self(),
    Watcher = spawn(fun() ->
        {ok, _Sub} = watch_mri:watch(self(), Mri, self()),
        Parent ! registered,
        receive die -> ok end
    end),
    receive registered -> ok after 1000 -> ct:fail(no_register) end,
    1 = watch_mri:active_count(),
    Watcher ! die,
    %% Give the monitor DOWN time to propagate.
    timer:sleep(100),
    0 = watch_mri:active_count(),
    ok.

%%====================================================================
%% realm_changed delivery
%%====================================================================

realm_changed_delivers_record_changed(_Config) ->
    RealmId = <<"io.macula">>,
    {Mri, _VR} = seed_user_in_cache(RealmId),
    {ok, Sub} = watch_mri:watch(self(), Mri, self()),
    %% Consume the current-value-on-subscribe delivery.
    {record_changed, _} = recv_watch(Sub, 1000),
    %% Simulate a realm change. realm_changed will: re-resolve
    %% (L5 still has the seeded VR since we don't invalidate here
    %% in the test) and deliver record_changed.
    ok = watch_mri:realm_changed(RealmId, changed),
    {record_changed, #{record_type := station_endpoint}} =
        recv_watch(Sub, 1000),
    ok = watch_mri:unwatch(Sub),
    ok.

realm_changed_tombstoned_when_resolve_fails(_Config) ->
    RealmId = <<"io.macula">>,
    {Mri, _VR} = seed_user_in_cache(RealmId),
    {ok, Sub} = watch_mri:watch(self(), Mri, self()),
    {record_changed, _} = recv_watch(Sub, 1000),
    %% Now wipe the L5 entry so re-resolution fails (a user MRI
    %% with no cache + no real DHT → {error, {not_resolvable_yet, user}}).
    cache_records:delete(l5, Mri),
    ok = watch_mri:realm_changed(RealmId, tombstoned),
    %% Re-resolve fails AND the change was tombstoned → deliver
    %% record_tombstoned.
    {record_tombstoned, Mri} = recv_watch(Sub, 1000),
    ok = watch_mri:unwatch(Sub),
    ok.

realm_changed_other_realm_is_ignored(_Config) ->
    {Mri, _} = seed_user_in_cache(<<"io.macula">>),
    {ok, Sub} = watch_mri:watch(self(), Mri, self()),
    {record_changed, _} = recv_watch(Sub, 1000),
    %% A change to a DIFFERENT realm — our watcher must not hear it.
    ok = watch_mri:realm_changed(<<"io.somewhere.else">>, changed),
    ok = no_watch_message(Sub, 300),
    ok = watch_mri:unwatch(Sub).

station_watcher_gets_current_value_not_realm_changes(_Config) ->
    StPk = crypto:strong_rand_bytes(32),
    {Mri, _VR} = seed_station_in_cache(StPk),
    {ok, Sub} = watch_mri:watch(self(), Mri, self()),
    %% Current value on subscribe.
    {record_changed, #{record_type := station_endpoint}} =
        recv_watch(Sub, 1000),
    %% Station MRIs are self-rooted (realm = undefined) — not
    %% matched by realm_changed.
    ok = watch_mri:realm_changed(<<"io.anything">>, changed),
    ok = no_watch_message(Sub, 300),
    ok = watch_mri:unwatch(Sub).
