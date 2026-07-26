%%% @doc Top-level supervisor for guide_realm_cert_lifecycle.
%%%
%%% Wires the bootstrap worker that triggers first-boot cert
%%% acquisition. The worker is launched once per daemon boot; it
%%% completes its check and either dispatches the acquire command or
%%% no-ops, then keeps running as a placeholder for the renewal-tick
%%% future slice.
%%% @end
-module(guide_realm_cert_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        #{id => provisional_cert_bootstrap,
          start => {provisional_cert_bootstrap, start_link, []},
          restart => permanent, type => worker}
    ],
    {ok, {SupFlags, Children}}.
