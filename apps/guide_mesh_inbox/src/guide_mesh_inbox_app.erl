%%% @doc Application module for guide_mesh_inbox.
%%%
%%% Owns the inbound mesh-FACT pipeline:
%%%
%%%   mesh FACT (delivered by hecate_mesh:subscribe callback)
%%%       -> receive_mesh_fact_listener:on_fact/3
%%%       -> receive_mesh_fact_v1 command
%%%       -> mesh_inbox_aggregate
%%%       -> mesh_fact_received_v1 domain event (in mesh_inbox_store)
%%%       -> projection joins the unified mesh_activity ETS with direction=in
%%%
%%% Also owns the bridge that consumes events from mesh_subscriptions_store
%%% (added / removed) and applies them to hecate_mesh as live
%%% subscribe / unsubscribe calls (installing the on_fact listener).
%%% @end
-module(guide_mesh_inbox_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    guide_mesh_inbox_sup:start_link().

stop(_State) ->
    ok.
