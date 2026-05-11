%%% @doc Supervisor for the verify_trust_chain desk.
%%%
%%% Worker is the state-machine driver. The 5 verifier modules
%%% (verify_frtl, verify_realm_directory, verify_endorsement,
%%% verify_leaf_record, verify_host_delegation) are pure-function
%%% modules called by the driver — no processes of their own.
-module(verify_trust_chain_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => verify_trust_chain,
          start   => {verify_trust_chain, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [verify_trust_chain]}
    ],
    {ok, {SupFlags, Children}}.
