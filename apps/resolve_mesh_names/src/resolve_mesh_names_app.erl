%%% @doc OTP application callback for resolve_mesh_names.
%%% Boots the slice-root supervisor.
%%% @end
-module(resolve_mesh_names_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    resolve_mesh_names_sup:start_link().

stop(_State) ->
    ok.
