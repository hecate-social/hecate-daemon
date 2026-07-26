%%% @doc LISTENER callback: inbound mesh FACT -> receive_mesh_fact_v1.
%%%
%%% This module exports the function passed to `hecate_mesh:subscribe/2'
%%% by `mesh_subscriptions_lifecycle_to_mesh'. Macula delivers each
%%% inbound FACT to the callback with arity 3: `(Topic, Payload, Meta)'.
%%%
%%% Behaviour:
%%%
%%%   * Self-publishes are dropped (Meta.publisher == own agent_id).
%%%     Phase-3-spec §3.7 default: no echo to own inbox.
%%%   * Non-map payloads are dropped with a warning (macula's wire is
%%%     CBOR-of-term; map is the legitimate shape).
%%%   * The dispatch into `mesh_inbox_aggregate' is delegated to a
%%%     short-lived worker process so the macula delivery pid is never
%%%     blocked on event-store I/O
%%%     (see memory: feedback_observer_inline_handler_blocks).
%%% @end
-module(receive_mesh_fact_listener).

-export([on_fact/3]).

-spec on_fact(binary(), term(), map()) -> ok.
on_fact(Topic, Payload, Meta) when is_binary(Topic), is_map(Payload), is_map(Meta) ->
    case is_self_publish(Meta) of
        true ->
            ok;
        false ->
            spawn(fun() -> dispatch_async(Topic, Payload, Meta) end),
            ok
    end;
on_fact(Topic, Payload, _Meta) ->
    logger:warning("[receive_mesh_fact_listener] dropping malformed inbound: topic=~p payload=~p",
                   [Topic, Payload]),
    ok.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

-spec is_self_publish(map()) -> boolean().
is_self_publish(#{publisher := Pub}) when is_binary(Pub) ->
    case safe_agent_id() of
        {ok, OwnId} when is_binary(OwnId) -> OwnId =:= Pub;
        _ -> false
    end;
is_self_publish(_) ->
    false.

%% hecate_identity:agent_id/0 returns the raw 32-byte ed25519 pubkey.
%% We guard against the gen_server not being up yet (early-boot) and
%% against a bare-value return shape vs `{ok, _}'.
safe_agent_id() ->
    case erlang:function_exported(hecate_identity, agent_id, 0) of
        false -> {error, no_identity_module};
        true ->
            try hecate_identity:agent_id() of
                {ok, Id} when is_binary(Id) -> {ok, Id};
                Id when is_binary(Id) -> {ok, Id};
                Other -> {error, {unexpected, Other}}
            catch
                _:_ -> {error, identity_unavailable}
            end
    end.

-spec dispatch_async(binary(), map(), map()) -> ok.
dispatch_async(Topic, Payload, Meta) ->
    Sender = maps:get(publisher, Meta, undefined),
    %% sig_verified: macula only delivers events that passed signature
    %% verification at the substrate layer; we surface that explicitly
    %% so downstream consumers don't have to assume it.
    SigVerified = Sender =/= undefined,
    case receive_mesh_fact_v1:new(#{
            topic          => Topic,
            fact           => Payload,
            sender_node_id => Sender,
            sender_mri     => undefined,
            sig_verified   => SigVerified,
            received_at    => erlang:system_time(millisecond)
         }) of
        {ok, Cmd} ->
            case maybe_receive_mesh_fact:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    ok;
                {error, Reason} ->
                    logger:warning("[receive_mesh_fact_listener] dispatch failed: topic=~s reason=~p",
                                   [Topic, Reason]),
                    ok
            end;
        {error, Reason} ->
            logger:warning("[receive_mesh_fact_listener] command build failed: ~p", [Reason]),
            ok
    end.
