%%% @doc Top-level supervisor for guide_mesh_subscriptions.
%%%
%%% No children at this layer yet. The mesh-side emitter (which calls
%%% `hecate_mesh:subscribe/2' / `hecate_mesh:unsubscribe/1' and installs
%%% the inbound LISTENER callback) lands in a follow-up slice once the
%%% `receive_mesh_fact' desk is wired in hecate_mesh.
%%%
%%% Until then this app only contributes the CMD + AGGREGATE layer:
%%% an agent can subscribe / unsubscribe, the events land in
%%% `mesh_subscriptions_store', the audit trail is intact. The
%%% delivery side is the next slice.
-module(guide_mesh_subscriptions_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [],
    {ok, {SupFlags, Children}}.
