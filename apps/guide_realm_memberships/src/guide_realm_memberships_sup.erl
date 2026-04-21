%%% @doc Top-level supervisor for guide_realm_memberships.
%%%
%%% Hosts the process manager that fetches K_realm from the realm
%%% server on `realm_membership_confirmed_v1`.
-module(guide_realm_memberships_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        #{
            id => on_realm_membership_confirmed_fetch_key,
            start => {evoq_event_handler, start_link,
                      [on_realm_membership_confirmed_fetch_key, #{}, #{}]},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [evoq_event_handler,
                        on_realm_membership_confirmed_fetch_key]
        },
        #{
            id => catch_up_realm_keys,
            start => {catch_up_realm_keys, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [catch_up_realm_keys]
        }
    ],
    {ok, {SupFlags, Children}}.
