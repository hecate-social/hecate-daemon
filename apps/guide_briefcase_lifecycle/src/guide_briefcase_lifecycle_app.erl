%%% @doc OTP application module for guide_briefcase_lifecycle.
-module(guide_briefcase_lifecycle_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    %% Register the mesh RPC advertisement for briefcase.get_chunk.
    %% hecate_mesh_client queues it and applies when the mesh activates —
    %% safe to call even before mesh is up.
    ok = serve_file_content_rpc:register(),
    guide_briefcase_lifecycle_sup:start_link().

stop(_State) ->
    ok.
