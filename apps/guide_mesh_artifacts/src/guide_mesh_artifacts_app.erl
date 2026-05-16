%%% @doc Application module for guide_mesh_artifacts.
%%%
%%% Owns the `share_mesh_artifact' desk (CMD with put_content side
%%% effect during command handling) and the `fetch_mesh_artifact' desk
%%% (REQUESTER-style read by MCID). Content-addressing means the FACT
%%% on the wire IS the artifact's hash — once put_content has returned
%%% an MCID, any reachable peer can pull the bytes; no emitter step.
%%% @end
-module(guide_mesh_artifacts_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    guide_mesh_artifacts_sup:start_link().

stop(_State) ->
    ok.
