%%% @doc Freshness guard for the share-license open path.
%%%
%%% The open path (consuming a license to decrypt a shared file) must
%%% refuse decryption when the local authorization state for a realm
%%% is stale. Otherwise a daemon that's been offline for days could
%%% decrypt content using a license that has since been revoked.
%%%
%%% ## State tracked
%%%
%%% Per-realm `last_license_catchup_at` millisecond timestamp. Updated
%%% by `catch_up_realm_licenses` after each successful sweep of the
%%% realm server's `io.macula.licenses.replay_events_v1` RPC.
%%%
%%% Stored as an extra field on the `realm_shared_keys` ETS entry —
%%% same table `hecate_realm_crypto` reads. Reusing that row avoids
%%% a separate table + start-up race.
%%%
%%% ## Freshness check
%%%
%%% `can_open/2` returns `ok` if:
%%%   1. We have a `last_license_catchup_at` and it is within
%%%      `license_staleness_threshold_ms` of `Now`, AND
%%%   2. The license has the `SL_CEK_USABLE` bit set, AND
%%%   3. The license's `expires_at` is in the future.
%%%
%%% Default threshold: 24h. Tunable via application env
%%% `hecate.license_staleness_threshold_ms`.
%%% @end
-module(hecate_license_guard).

-export([can_open/2, can_open_file/2]).
-export([stamp_catchup/1, stamp_catchup/2, last_catchup/1]).
-export([default_threshold_ms/0]).

-define(SHARED_KEYS_TABLE, realm_shared_keys).
-define(ACCEPTED_LICENSES_TABLE, my_accepted_share_licenses).
-define(DEFAULT_THRESHOLD_MS, 86400000). %% 24h
%% Mirror of ?SL_CEK_USABLE from guide_share_license_lifecycle's
%% share_license_status.hrl. Duplicated here because `shared` lives
%% below `guide_share_license_lifecycle` in the dep tree and cannot
%% include its hrl. If the canonical bit value changes, update both.
-define(SL_CEK_USABLE, 16).

-type license() :: map().
-type realm()   :: binary().

%%====================================================================
%% API
%%====================================================================

%% @doc Decide whether the open path may use `License` for `Realm`.
%% Returns `ok` when the authorization state is fresh, the license is
%% usable, and not expired. Returns `{error, Reason}` otherwise —
%% callers should treat every error as a refusal.
-spec can_open(license(), realm()) -> ok | {error, atom()}.
can_open(License, Realm) when is_map(License), is_binary(Realm) ->
    Now = erlang:system_time(millisecond),
    Threshold = threshold_ms(),
    with_step(fun() -> check_expiry(License, Now) end,
        fun() -> with_step(fun() -> check_usable(License) end,
            fun() -> check_freshness(Realm, Now, Threshold) end) end);
can_open(_License, _Realm) ->
    {error, bad_args}.

%% @doc Open-path convenience: look up the accepted share-license for a
%% `FileId` and decide whether its open path is permitted. Reads the
%% `my_accepted_share_licenses` ETS (owned by `project_share_licenses`)
%% directly by name to avoid a shared → project circular dep. Returns
%% `{error, no_license}` when no accepted license exists for the file.
%%
%% `Realm` is passed explicitly (not read off the license entry) so
%% the caller can enforce that the realm matches the calling context —
%% defends against a license for realm A being used to open content
%% rendered under realm B.
-spec can_open_file(binary(), realm()) -> ok | {error, atom()}.
can_open_file(FileId, Realm)
  when is_binary(FileId), is_binary(Realm) ->
    case lookup_accepted(FileId) of
        {ok, #{realm := LicenseRealm} = License}
          when LicenseRealm =:= Realm ->
            can_open(License, Realm);
        {ok, _License} ->
            {error, license_realm_mismatch};
        {error, not_found} ->
            {error, no_license}
    end;
can_open_file(_FileId, _Realm) ->
    {error, bad_args}.

%% @doc Record a successful catch-up sweep for `Realm` at `now()`.
-spec stamp_catchup(realm()) -> ok.
stamp_catchup(Realm) ->
    stamp_catchup(Realm, erlang:system_time(millisecond)).

%% @doc Record a successful catch-up sweep for `Realm` at a specific
%% timestamp — test hook.
-spec stamp_catchup(realm(), integer()) -> ok.
stamp_catchup(Realm, AtMs) when is_binary(Realm), is_integer(AtMs) ->
    case ets:whereis(?SHARED_KEYS_TABLE) of
        undefined -> ok;
        _ ->
            case ets:lookup(?SHARED_KEYS_TABLE, Realm) of
                [{_, Entry}] ->
                    Updated = Entry#{last_license_catchup_at => AtMs},
                    ets:insert(?SHARED_KEYS_TABLE, {Realm, Updated}),
                    ok;
                [] ->
                    %% No realm key stored yet — stamp alone with no
                    %% key bytes has no meaning. Silent no-op.
                    ok
            end
    end.

%% @doc Read the last catch-up timestamp for a realm, or `undefined`.
-spec last_catchup(realm()) -> integer() | undefined.
last_catchup(Realm) when is_binary(Realm) ->
    case ets:whereis(?SHARED_KEYS_TABLE) of
        undefined -> undefined;
        _ ->
            case ets:lookup(?SHARED_KEYS_TABLE, Realm) of
                [{_, Entry}] -> maps:get(last_license_catchup_at, Entry, undefined);
                []           -> undefined
            end
    end.

-spec default_threshold_ms() -> pos_integer().
default_threshold_ms() ->
    ?DEFAULT_THRESHOLD_MS.

%%====================================================================
%% Internal
%%====================================================================

threshold_ms() ->
    application:get_env(hecate, license_staleness_threshold_ms,
                        ?DEFAULT_THRESHOLD_MS).

lookup_accepted(FileId) ->
    case ets:whereis(?ACCEPTED_LICENSES_TABLE) of
        undefined -> {error, not_found};
        _ ->
            case ets:lookup(?ACCEPTED_LICENSES_TABLE, FileId) of
                [{_, Entry}] -> {ok, Entry};
                []           -> {error, not_found}
            end
    end.

with_step(CheckFun, Continuation) ->
    case CheckFun() of
        ok              -> Continuation();
        {error, _} = E  -> E
    end.

check_expiry(License, Now) ->
    case maps:get(expires_at, License, undefined) of
        undefined -> {error, license_no_expiry};
        At when is_integer(At), At > Now -> ok;
        _ -> {error, license_expired}
    end.

check_usable(License) ->
    Status = maps:get(status, License, 0),
    case is_integer(Status) andalso evoq_bit_flags:has(Status, ?SL_CEK_USABLE) of
        true  -> ok;
        false -> {error, license_not_usable}
    end.

check_freshness(Realm, Now, Threshold) ->
    case last_catchup(Realm) of
        undefined ->
            {error, license_state_stale};
        At when is_integer(At), (Now - At) < Threshold ->
            ok;
        _ ->
            {error, license_state_stale}
    end.
