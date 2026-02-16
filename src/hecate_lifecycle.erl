%%%-------------------------------------------------------------------
%%% @doc Daemon lifecycle state file management.
%%%
%%% Writes daemon.pid and daemon.state files to ~/.hecate/ so that
%%% TUI/web clients can distinguish between daemon states:
%%%   - starting: socket up, domain apps not yet loaded
%%%   - running: all domain apps booted, full routes available
%%%   - stopping: clean shutdown in progress
%%%   - (files missing): daemon not running or crashed
%%%   - (stale PID): daemon crashed without cleanup
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_lifecycle).

-export([init/0, set_state/1, cleanup/0, hecate_dir/0]).

%%--------------------------------------------------------------------
%% @doc Initialize lifecycle files. Writes daemon.pid and sets state
%% to `starting`. Called early in hecate_app:start/2.
%% @end
%%--------------------------------------------------------------------
-spec init() -> ok.
init() ->
    Dir = hecate_dir(),
    filelib:ensure_dir(filename:join(Dir, "x")),
    PidFile = filename:join(Dir, "daemon.pid"),
    ok = file:write_file(PidFile, os:getpid()),
    set_state(starting).

%%--------------------------------------------------------------------
%% @doc Update the daemon.state file.
%% @end
%%--------------------------------------------------------------------
-spec set_state(starting | running | stopping) -> ok.
set_state(State) when State =:= starting; State =:= running; State =:= stopping ->
    File = filename:join(hecate_dir(), "daemon.state"),
    ok = file:write_file(File, atom_to_list(State)).

%%--------------------------------------------------------------------
%% @doc Remove PID and state files on clean shutdown.
%% @end
%%--------------------------------------------------------------------
-spec cleanup() -> ok.
cleanup() ->
    Dir = hecate_dir(),
    _ = file:delete(filename:join(Dir, "daemon.pid")),
    _ = file:delete(filename:join(Dir, "daemon.state")),
    ok.

%%--------------------------------------------------------------------
%% @doc Resolve the ~/.hecate/ directory path.
%% @end
%%--------------------------------------------------------------------
-spec hecate_dir() -> string().
hecate_dir() ->
    case os:getenv("HOME") of
        false -> "/tmp/hecate";
        Home -> filename:join(Home, ".hecate")
    end.
