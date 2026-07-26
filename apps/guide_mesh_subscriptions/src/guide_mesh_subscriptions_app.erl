%%% @doc Application module for guide_mesh_subscriptions.
%%%
%%% Owns two desks that together manage the agent-facing mesh
%%% subscription lifecycle: `add_mesh_subscription' records the
%%% intention to subscribe to a topic; `remove_mesh_subscription'
%%% records the intention to unsubscribe. Both are idempotent at the
%%% aggregate boundary: re-adding an existing topic or removing an
%%% unsubscribed one produces no event.
%%%
%%% The matching domain events (`mesh_subscription_added_v1' /
%%% `mesh_subscription_removed_v1') are pushed into the mesh layer by
%%% an EMITTER that owns the topic-to-subscription-ref bookkeeping and
%%% installs the inbound LISTENER callback. That EMITTER lives in its
%%% own slice and is wired in once the matching `receive_mesh_fact'
%%% LISTENER desk lands in hecate_mesh.
%%% @end
-module(guide_mesh_subscriptions_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    guide_mesh_subscriptions_sup:start_link().

stop(_State) ->
    ok.
