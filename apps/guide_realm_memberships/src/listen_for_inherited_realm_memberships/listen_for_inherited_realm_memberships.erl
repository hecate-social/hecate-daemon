%%% @doc Listen for realm-membership events relayed across the site.
%%%
%%% A "site" is the cluster of co-located daemons. Headless daemons
%%% can't OAuth; they depend on an attended daemon in the same site to
%%% go through the realm join flow. When the attended daemon writes a
%%% realm-membership event to its realm_memberships_store,
%%% relay_realm_events_to_site re-publishes it over the
%%% boot_daemon:site_daemons_group/0 pg seam. This gen_server — running
%%% on every daemon — receives those {site_realm_event, ...} messages:
%%%
%%%   * initiated / confirmed → informational. We do NOT replicate the
%%%     attended daemon's membership record.
%%%   * credentials_secured  → hand the (cookie-encrypted) blob to
%%%     hecate_realm_session:provision_from_inherited_creds/2, which
%%%     decrypts it, takes ONLY the refresh token, and calls the
%%%     realm's /api/v1/cluster/provision with this daemon's own pubkey
%%%     to mint this daemon's OWN per-daemon cert
%%%     (mri:app:io.macula/<org>/_hecate-<daemon>) and OWN local
%%%     membership.
%%%
%%% Dedup: the relay re-delivers credentials_secured many times during
%%% a catch-up replay, and the attended daemon may carry several
%%% memberships (some with revoked tokens). We trigger at most one
%%% provision worker per distinct membership_id this session; the
%%% worker also bails if a membership already exists
%%% (hecate_realm_session:already_provisioned/0, an ETS read-model
%%% check) so a daemon restart doesn't re-mint.
%%% @end
-module(listen_for_inherited_realm_memberships).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Group = boot_daemon:site_daemons_group(),
    Base = #{group => Group, provisioned_for => #{}},
    case safe_join(Group) of
        ok ->
            logger:info("[site_realm] joined site pg group ~p", [Group]),
            {ok, Base#{joined => true}};
        {error, Reason} ->
            logger:warning("[site_realm] pg join failed (~p); retrying in 2s", [Reason]),
            erlang:send_after(2000, self(), retry_join),
            {ok, Base#{joined => false}}
    end.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(retry_join, #{joined := false, group := Group} = State) ->
    case safe_join(Group) of
        ok ->
            logger:info("[site_realm] joined site pg group ~p (retry)", [Group]),
            {noreply, State#{joined => true}};
        {error, _} ->
            erlang:send_after(2000, self(), retry_join),
            {noreply, State}
    end;

handle_info({site_realm_event, <<"realm_credentials_secured_v1">>, Payload, FromDaemon}, State) ->
    logger:info("[site_realm] received realm_credentials_secured_v1 from ~p", [FromDaemon]),
    NP = normalize(Payload),
    MembershipId = maps:get(membership_id, NP, <<>>),
    EncCreds = maps:get(encrypted_credentials, NP, <<>>),
    Done = maps:get(provisioned_for, State, #{}),
    case {byte_size(EncCreds), maps:is_key(MembershipId, Done)} of
        {0, _} ->
            logger:warning("[site_realm] inherited creds: no encrypted_credentials"),
            {noreply, State};
        {_, true} ->
            %% Already spawned a provision attempt for this membership this session.
            {noreply, State};
        {_, false} ->
            spawn(fun() ->
                catch hecate_realm_session:provision_from_inherited_creds(MembershipId, EncCreds)
            end),
            {noreply, State#{provisioned_for => Done#{MembershipId => true}}}
    end;

handle_info({site_realm_event, EventType, Payload, FromDaemon}, State) ->
    logger:info("[site_realm] received ~s from ~p", [EventType, FromDaemon]),
    note_inherited(EventType, Payload),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #{group := Group}) ->
    catch pg:leave(Group, self()),
    ok;
terminate(_Reason, _) -> ok.

%%====================================================================
%% Internal
%%====================================================================

%% initiated/confirmed are informational — we mint our own membership
%% when credentials_secured arrives, not a copy of the attended one's.
note_inherited(<<"realm_membership_initiated_v1">>, _Payload) ->
    logger:debug("[site_realm] noted realm_membership_initiated_v1"),
    ok;
note_inherited(<<"realm_membership_confirmed_v1">>, _Payload) ->
    logger:debug("[site_realm] noted realm_membership_confirmed_v1"),
    ok;
note_inherited(Other, _) ->
    logger:debug("[site_realm] ignoring inherited event type: ~s", [Other]),
    ok.

%% @private evoq events arrive with atom OR binary keys depending on
%% the path. Flatten to atom keys for downstream lookups.
normalize(Payload) when is_map(Payload) ->
    maps:fold(fun
        (K, V, Acc) when is_binary(K) ->
            try Acc#{binary_to_existing_atom(K) => V}
            catch error:badarg -> Acc#{K => V}
            end;
        (K, V, Acc) ->
            Acc#{K => V}
    end, #{}, Payload).

safe_join(Group) ->
    try pg:join(Group, self())
    catch error:badarg -> {error, pg_scope_not_ready};
          Class:Reason -> {error, {Class, Reason}}
    end.
