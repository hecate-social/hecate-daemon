%%% @doc Supervisor for the realm-gitops-init responder desk.
%%%
%%% One child: the desk worker that registers the mesh advertisement.
%%% @end
-module(respond_to_realm_gitops_init_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy  => one_for_one,
        intensity => 5,
        period    => 10
    },
    Children = [
        #{id      => respond_to_realm_gitops_init,
          start   => {respond_to_realm_gitops_init, start_link, []},
          restart => permanent,
          type    => worker}
    ],
    {ok, {SupFlags, Children}}.
