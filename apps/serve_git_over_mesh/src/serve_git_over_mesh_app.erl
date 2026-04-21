%%% @doc OTP application module for serve_git_over_mesh.
%%%
%%% Phase 2 of PLAN_GIT_OVER_MESH.md — wires repo-lifecycle events to
%%% on-disk bare repository creation and mesh procedure advertisements.
%%% @end
-module(serve_git_over_mesh_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    ok = filelib:ensure_path(repo_paths:root()),
    ok = load_realm_server_allowlist(),
    serve_git_over_mesh_sup:start_link().

%% @private Copy the `MACULA_REALM_SERVER_DIDS` env var (comma-
%% separated) into `hecate/realm_server_dids` application env. Empty
%% or unset var → empty allowlist (fail-closed: every realm-gitops-
%% init call is rejected until an operator populates this list). The
%% var belongs to `hecate/` rather than `serve_git_over_mesh/`
%% because it describes a trust policy that may be consumed by other
%% responders in the future.
load_realm_server_allowlist() ->
    Dids =
        case os:getenv("MACULA_REALM_SERVER_DIDS") of
            false -> application:get_env(hecate, realm_server_dids, []);
            ""    -> application:get_env(hecate, realm_server_dids, []);
            Raw   ->
                [list_to_binary(string:trim(D))
                 || D <- string:split(Raw, ",", all),
                    string:trim(D) =/= ""]
        end,
    application:set_env(hecate, realm_server_dids, Dids),
    case Dids of
        [] ->
            logger:notice(
              "[serve_git_over_mesh] realm_server_dids empty — all "
              "realm-initiated gitops provisioning calls will be "
              "rejected (set MACULA_REALM_SERVER_DIDS)");
        _ ->
            logger:info(
              "[serve_git_over_mesh] realm_server_dids allowlist has ~b entry(ies)",
              [length(Dids)])
    end,
    ok.

stop(_State) ->
    ok.
