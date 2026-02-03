%%% @doc serve_llm top-level supervisor
%%%
%%% Supervises the LLM backend client and related workers.
%%% VERTICAL SLICING: This domain owns its infrastructure.
-module(serve_llm_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    %% LLM backend is stateless - just a module with functions
    %% No workers needed for Phase 1 (sync HTTP calls)
    %% Phase 2 will add: model announcer, RPC handler
    Children = [],

    logger:info("[serve_llm] Supervisor started"),
    {ok, {SupFlags, Children}}.
