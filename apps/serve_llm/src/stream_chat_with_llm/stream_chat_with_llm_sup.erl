%%% @doc Supervisor for the stream_chat_with_llm desk.
%%%
%%% First Phase 4 pilot consumer of macula streaming RPC
%%% (PLAN_MACULA_STREAMING.md). Replaces the cross-node "wait for the
%%% whole answer" call shape with token-by-token streaming.
-module(stream_chat_with_llm_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{id => stream_chat_with_llm,
          start => {stream_chat_with_llm, start_link, []},
          restart => permanent,
          shutdown => 5000,
          type => worker}
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
