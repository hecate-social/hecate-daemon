%%% @doc Listen for realm-membership events relayed from cluster peers.
%%%
%%% Headless beam nodes can't OAuth. They depend on an attended peer
%%% (host00) to go through the realm join flow. When the attended
%%% node's local realm_memberships_store produces an
%%% initiated/confirmed/credentials_secured event, the relay PM
%%% broadcasts it via pg. This gen_server — running on every node —
%%% receives those broadcasts:
%%%   * initiated / confirmed → re-dispatch the matching command
%%%     against the local store, so the membership record exists
%%%     locally (idempotent: {error, already_*} on re-receipt — no
%%%     recursive storm via the relay PM).
%%%   * credentials_secured  → DO NOT store the attended node's creds
%%%     blob (that would run this node with the attended node's
%%%     identity). Instead hand the inherited (cookie-encrypted) blob
%%%     to hecate_realm_session:provision_from_inherited_creds/2,
%%%     which decrypts it, takes ONLY the refresh token, and calls the
%%%     realm's /api/v1/cluster/provision endpoint with this node's
%%%     own pubkey — minting this node's OWN per-node certificate
%%%     (mri:app:io.macula/<org>/_hecate-<node>).
%%% @end
-module(listen_for_inherited_realm_memberships).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Group = boot_daemon:inherited_pg_group(),
    case safe_join(Group) of
        ok ->
            logger:info("[inherit_realm] joined pg group ~p", [Group]),
            {ok, #{joined => true, group => Group}};
        {error, Reason} ->
            logger:warning("[inherit_realm] pg join failed (~p); retrying in 2s", [Reason]),
            erlang:send_after(2000, self(), retry_join),
            {ok, #{joined => false, group => Group}}
    end.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(retry_join, #{joined := false, group := Group} = State) ->
    case safe_join(Group) of
        ok ->
            logger:info("[inherit_realm] joined pg group ~p (retry)", [Group]),
            {noreply, State#{joined => true}};
        {error, _} ->
            erlang:send_after(2000, self(), retry_join),
            {noreply, State}
    end;

handle_info({inherited_realm_event, EventType, Payload, FromNode}, State) ->
    logger:info("[inherit_realm] received ~s from ~p", [EventType, FromNode]),
    dispatch_inherited(EventType, Payload),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #{group := Group}) ->
    catch pg:leave(Group, self()),
    ok;
terminate(_Reason, _) -> ok.

%%====================================================================
%% Dispatch
%%====================================================================

dispatch_inherited(<<"realm_membership_initiated_v1">>, _Payload) ->
    %% Informational only. We do NOT replicate the attended node's
    %% membership record — when its `realm_credentials_secured_v1'
    %% arrives we mint our OWN membership locally (with our own cert
    %% from /api/v1/cluster/provision). So nothing to do here.
    logger:debug("[inherit_realm] noted peer realm_membership_initiated_v1"),
    ok;

dispatch_inherited(<<"realm_membership_confirmed_v1">>, _Payload) ->
    logger:debug("[inherit_realm] noted peer realm_membership_confirmed_v1"),
    ok;

dispatch_inherited(<<"realm_credentials_secured_v1">>, Payload) ->
    %% Hand the inherited (cookie-encrypted) blob to hecate_realm_session,
    %% which decrypts it, takes ONLY the refresh token, calls the realm's
    %% /api/v1/cluster/provision with OUR own pubkey to get OUR own
    %% per-node cert, and mints OUR own local membership (initiate ->
    %% confirm -> secure). HTTP — do it off this gen_server.
    NP = normalize(Payload),
    MembershipId = maps:get(membership_id, NP, <<>>),
    EncCreds = maps:get(encrypted_credentials, NP, <<>>),
    case byte_size(EncCreds) of
        0 -> logger:warning("[inherit_realm] inherited creds: no encrypted_credentials");
        _ ->
            spawn(fun() ->
                catch hecate_realm_session:provision_from_inherited_creds(MembershipId, EncCreds)
            end)
    end,
    ok;

dispatch_inherited(Other, _) ->
    logger:debug("[inherit_realm] ignoring unknown event type: ~s", [Other]),
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

%%====================================================================
%% pg helpers
%%====================================================================

safe_join(Group) ->
    try pg:join(Group, self())
    catch error:badarg -> {error, pg_scope_not_ready};
          Class:Reason -> {error, {Class, Reason}}
    end.
