%%% @doc OTP application module for guide_briefcase_lifecycle.
-module(guide_briefcase_lifecycle_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    %% Register the mesh RPC advertisements for briefcase content
    %% access. hecate_mesh_client queues them and applies when the
    %% mesh activates — safe to call even before mesh is up.
    %%   - get_chunk         (legacy unary, whole-file in one reply)
    %%   - get_chunk_stream  (server-stream chunks; pilot of
    %%                        PLAN_MACULA_STREAMING.md)
    ok = serve_file_content_rpc:register(),
    ok = stream_file_content_rpc:register(),
    guide_briefcase_lifecycle_sup:start_link().

stop(_State) ->
    ok.
