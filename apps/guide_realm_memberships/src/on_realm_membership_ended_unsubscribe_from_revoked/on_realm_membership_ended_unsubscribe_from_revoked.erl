%%% @doc Process Manager: realm_membership_ended_v1 →
%%% listen_for_membership_revoked:unsubscribe().
%%%
%%% Symmetric to `on_realm_membership_confirmed_subscribe_to_revoked`.
%%% When this daemon's membership ends — either because we received
%%% a revoke fact and dispatched `end_realm_membership_v1` locally,
%%% or because the user actively resigned — drop the
%%% membership-revoked subscription so a former member doesn't keep
%%% listening for revoke facts that no longer apply.
%%%
%%% Idempotent: cast is a no-op if no active subscription.
%%% @end
-module(on_realm_membership_ended_unsubscribe_from_revoked).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"realm_membership_ended_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, _Event, _Metadata, State) ->
    listen_for_membership_revoked:unsubscribe(),
    logger:info("[pm.unsubscribe_from_revoked] requested unsubscribe"),
    {ok, State}.
