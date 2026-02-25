%%% @doc Supervisor for license_revoked_v1 -> licenses projection.
-module(license_revoked_v1_to_licenses_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{id => listener,
          start => {on_license_revoked_v1_to_sqlite_licenses, start_link, []},
          restart => permanent, type => worker}
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
