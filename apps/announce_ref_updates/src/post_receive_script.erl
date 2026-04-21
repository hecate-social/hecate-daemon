%%% @doc Render the post-receive hook script body for a given repo.
%%%
%%% The hook is installed at `<repo>.git/hooks/post-receive` by
%%% `git_init_cmd:install_hook/2`. For every ref update it connects
%%% to the `announce_ref_updates` Unix socket and writes a single
%%% space-delimited line:
%%%
%%%   `<repo_id> <old_sha> <new_sha> <refname>\n`
%%%
%%% `socat` is preferred; if missing we fall back to `nc -U`. Either
%%% way the hook never fails the push — listener absence logs a
%%% warning on stderr but returns 0.
%%% @end
-module(post_receive_script).

-export([render/1, socket_path/0]).

-spec render(binary()) -> binary().
render(RepoId) when is_binary(RepoId) ->
    Sock = socket_path(),
    SockBin = unicode:characters_to_binary(Sock),
    RepoBin = escape_for_shell(RepoId),
    iolist_to_binary([
        <<"#!/usr/bin/env bash\n">>,
        <<"# Hecate post-receive hook — publishes ref-updated FACT via Unix socket.\n">>,
        <<"# Auto-installed by serve_git_over_mesh/initialize_repo_on_disk.\n">>,
        <<"set -euo pipefail\n">>,
        <<"SOCK=\"${HECATE_REF_UPDATES_SOCK:-">>, SockBin, <<"}\"\n">>,
        <<"REPO_ID=\"">>, RepoBin, <<"\"\n">>,
        <<"write_line() {\n">>,
        <<"  local line=\"$1\"\n">>,
        <<"  if command -v socat >/dev/null 2>&1; then\n">>,
        <<"    printf '%s\\n' \"$line\" | socat - \"UNIX-CONNECT:${SOCK}\" 2>/dev/null || true\n">>,
        <<"  elif command -v nc >/dev/null 2>&1; then\n">>,
        <<"    printf '%s\\n' \"$line\" | nc -U -w 1 \"$SOCK\" 2>/dev/null || true\n">>,
        <<"  else\n">>,
        <<"    echo \"[hecate-post-receive] socat / nc missing — skipping\" >&2\n">>,
        <<"  fi\n">>,
        <<"}\n">>,
        <<"if [ -S \"$SOCK\" ]; then\n">>,
        <<"  while IFS=' ' read -r oldsha newsha refname; do\n">>,
        <<"    write_line \"${REPO_ID} ${oldsha} ${newsha} ${refname}\"\n">>,
        <<"  done\n">>,
        <<"else\n">>,
        <<"  echo \"[hecate-post-receive] socket $SOCK absent — ref update not published\" >&2\n">>,
        <<"fi\n">>
    ]).

%% @doc Resolve the socket path. Env override wins; otherwise prefer
%% `$XDG_RUNTIME_DIR/hecate/ref_updates.sock` (dev-friendly), falling
%% back to `/run/hecate/ref_updates.sock` (systemd-style deploys).
-spec socket_path() -> file:filename().
socket_path() ->
    case os:getenv("HECATE_REF_UPDATES_SOCK") of
        Val when is_list(Val), Val =/= "" -> Val;
        _ -> default_socket_path()
    end.

%%====================================================================
%% Internal
%%====================================================================

default_socket_path() ->
    case os:getenv("XDG_RUNTIME_DIR") of
        Xdg when is_list(Xdg), Xdg =/= "" ->
            filename:join([Xdg, "hecate", "ref_updates.sock"]);
        _ ->
            "/run/hecate/ref_updates.sock"
    end.

escape_for_shell(Bin) when is_binary(Bin) ->
    %% Repo IDs are ULID/UUID-shaped in practice — no quoting needed,
    %% but defend against anything odd by stripping control chars.
    Cleaned = [C || <<C>> <= Bin, C >= 32, C =/= $", C =/= $\\ ],
    unicode:characters_to_binary(Cleaned).
