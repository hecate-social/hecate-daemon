%%% @doc Top-level supervisor for guide_mesh_inbox.
%%%
%%% Wires the bridge that applies mesh_subscriptions_store events to the
%%% live `hecate_mesh' layer. The bridge subscribes to that store, reacts
%%% to `mesh_subscription_added_v1' by calling `hecate_mesh:subscribe/2'
%%% with `receive_mesh_fact_listener:on_fact/3' as the callback, and
%%% reacts to `mesh_subscription_removed_v1' by calling
%%% `hecate_mesh:unsubscribe/1'.
%%% @end
-module(guide_mesh_inbox_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        %% Bridge: mesh_subscriptions_store domain events -> hecate_mesh
        %% subscribe / unsubscribe + installs the on_fact listener.
        #{id => mesh_subscriptions_lifecycle_to_mesh,
          start => {evoq_event_handler, start_link,
                    [mesh_subscriptions_lifecycle_to_mesh, #{}]},
          restart => permanent, type => worker}
    ],
    {ok, {SupFlags, Children}}.
