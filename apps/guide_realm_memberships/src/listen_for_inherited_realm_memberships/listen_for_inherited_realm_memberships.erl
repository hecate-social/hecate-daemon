%%% @doc Listen for realm-membership events relayed from cluster peers.
%%%
%%% Headless beam nodes can't OAuth. They depend on an attended peer
%%% (host00) to go through the realm join flow. When the attended
%%% node's local realm_memberships_store produces an
%%% initiated/confirmed/credentials_secured event, the relay PM
%%% broadcasts it via pg. This gen_server — running on every node —
%%% receives those broadcasts and re-dispatches the matching command
%%% against the local store so the beam's own aggregate ends up in
%%% the same state.
%%%
%%% Loop prevention: aggregate commands are idempotent
%%% ({error, already_initiated | already_confirmed |
%%% credentials_already_secured}). When the receiver writes its own
%%% event, the relay PM on that node sees it, tries to rebroadcast —
%%% but every peer is already in state, so their dispatch returns
%%% already_* without producing a new event. No recursive storm.
%%%
%%% For the confirmed event we also synthesise an initiate if the
%%% local aggregate isn't yet initiated — otherwise `confirm` would
%%% fail with not_initiated on a peer that hasn't yet received the
%%% initiate broadcast.
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

dispatch_inherited(<<"realm_membership_initiated_v1">>, Payload) ->
    dispatch(maybe_initiate_realm_membership, handle_from_map, [normalize(Payload)],
             initiate_realm_membership);

dispatch_inherited(<<"realm_membership_confirmed_v1">>, Payload) ->
    %% Confirm requires the aggregate to be initiated locally; if the
    %% initiate broadcast arrived out of order (or was missed because
    %% this node booted late), synthesise one from the confirm payload
    %% — it carries membership_id + realm_id, which is enough.
    NormPayload = normalize(Payload),
    _ = dispatch(maybe_initiate_realm_membership, handle_from_map,
                 [NormPayload], initiate_realm_membership),
    dispatch(maybe_confirm_realm_membership, handle_from_map, [NormPayload],
             confirm_realm_membership);

dispatch_inherited(<<"realm_credentials_secured_v1">>, Payload) ->
    dispatch(maybe_secure_realm_credentials, handle_from_map, [normalize(Payload)],
             secure_realm_credentials);

dispatch_inherited(Other, _) ->
    logger:debug("[inherit_realm] ignoring unknown event type: ~s", [Other]),
    ok.

%% @private evoq events arrive with atom OR binary keys depending on
%% the path. Flatten to atom keys so handle_from_map's atomised lookups
%% succeed without needing dual-key logic in every downstream module.
normalize(Payload) when is_map(Payload) ->
    maps:fold(fun
        (K, V, Acc) when is_binary(K) ->
            try Acc#{binary_to_existing_atom(K) => V}
            catch error:badarg -> Acc#{K => V}
            end;
        (K, V, Acc) ->
            Acc#{K => V}
    end, #{}, Payload).

dispatch(Module, Fun, Args, Label) ->
    case code:ensure_loaded(Module) of
        {module, Module} ->
            case erlang:function_exported(Module, Fun, length(Args)) of
                true -> do_apply(Module, Fun, Args, Label);
                false ->
                    logger:warning("[inherit_realm] ~p:~p/~b not exported; skipping ~p",
                                   [Module, Fun, length(Args), Label])
            end;
        {error, LoadReason} ->
            logger:warning("[inherit_realm] cannot load ~p (~p); skipping ~p",
                           [Module, LoadReason, Label])
    end.

do_apply(Module, Fun, Args, Label) ->
    try apply(Module, Fun, Args) of
        {ok, _V, _E}              -> ok;
        {ok, _Events}             -> ok;
        {error, already_initiated} -> ok;
        {error, already_confirmed} -> ok;
        {error, credentials_already_secured} -> ok;
        {error, not_initiated}    -> ok;   %% raced initiate ordering — will retry next event
        {error, Reason} ->
            logger:warning("[inherit_realm] ~p dispatch failed: ~p", [Label, Reason])
    catch Class:Reason:Stack ->
        logger:warning("[inherit_realm] ~p dispatch exception ~p:~p~n~p",
                       [Label, Class, Reason, Stack])
    end.

%%====================================================================
%% pg helpers
%%====================================================================

safe_join(Group) ->
    try pg:join(Group, self())
    catch error:badarg -> {error, pg_scope_not_ready};
          Class:Reason -> {error, {Class, Reason}}
    end.
