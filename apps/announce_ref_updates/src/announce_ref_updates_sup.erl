%%% @doc Top-level supervisor for announce_ref_updates.
%%%
%%% Supervises two desks, each with its own supervisor:
%%%
%%%   - `receive_ref_update_rpc_sup` — Unix-socket listener that
%%%     receives lines from post-receive hooks.
%%%   - `publish_ref_updated_fact_sup` — publishes each received line
%%%     as a mesh FACT.
%%% @end
-module(announce_ref_updates_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        %% Order matters — the fact publisher must be up before the
        %% socket listener hands off work.
        #{id      => publish_ref_updated_fact_sup,
          start   => {publish_ref_updated_fact_sup, start_link, []},
          restart => permanent,
          type    => supervisor},
        #{id      => receive_ref_update_rpc_sup,
          start   => {receive_ref_update_rpc_sup, start_link, []},
          restart => permanent,
          type    => supervisor}
    ],
    {ok, {SupFlags, Children}}.
