%%% @doc Desk supervisor for the Unix-socket listener.
-module(receive_ref_update_rpc_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Worker = #{id      => receive_ref_update_rpc,
               start   => {receive_ref_update_rpc, start_link, []},
               restart => permanent,
               type    => worker},
    {ok, {SupFlags, [Worker]}}.
