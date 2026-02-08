%%% @doc hecate_telemetry top-level supervisor
-module(hecate_telemetry_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker
        {hecate_telemetry_store,
            {hecate_telemetry_store, start_link, []},
            permanent, 5000, worker, [hecate_telemetry_store]}
    ],
    {ok, {{one_for_one, 10, 10}, Children}}.
