%%% @doc Top-level supervisor for guide_briefcase_lifecycle.
%%%
%%% Supervises:
%%%   - mesh emitters (Phase B + later)
%%%   - briefcase_download_progress ETS owner
%%%   - briefcase_download_sup (simple_one_for_one for async download
%%%     workers — Phase 4 async model)
%%%   - on_file_download_started_fetch_bytes evoq handler (the PM
%%%     that spawns the worker on each file_download_started_v1)
%%% @end
-module(guide_briefcase_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy  => one_for_one,
        intensity => 10,
        period    => 10
    },
    Children = [
        %% Mesh emitters — domain events to integration FACTs.
        emitter(file_shared_v1_to_mesh),

        %% Progress ETS — owned by a tiny gen_server so the table
        %% lives as long as the supervisor does.
        #{id => briefcase_download_progress_owner,
          start => {briefcase_download_progress_owner, start_link, []},
          restart => permanent, shutdown => 5000, type => worker,
          modules => [briefcase_download_progress_owner]},

        %% Per-download worker pool.
        #{id => briefcase_download_sup,
          start => {briefcase_download_sup, start_link, []},
          restart => permanent, shutdown => 5000, type => supervisor,
          modules => [briefcase_download_sup]},

        %% Process manager: file_download_started_v1 -> spawn worker.
        emitter(on_file_download_started_fetch_bytes)
    ],
    {ok, {SupFlags, Children}}.

emitter(Mod) ->
    #{id      => Mod,
      start   => {evoq_event_handler, start_link, [Mod, #{}]},
      restart => permanent,
      type    => worker}.
