%%% @doc guide_sale_lifecycle top-level supervisor
%%%
%%% Supervises PG emitters for sale lifecycle events.
%%% @end
-module(guide_sale_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    Children = [
        %% -- PG emitters --
        #{id => sale_initiated_v1_to_pg,
          start => {evoq_event_handler, start_link, [sale_initiated_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => sale_archived_v1_to_pg,
          start => {evoq_event_handler, start_link, [sale_archived_v1_to_pg, #{}]},
          restart => permanent, type => worker},

        %% -- Cross-context process managers --
        #{id => on_procurement_initiated_initiate_sale,
          start => {evoq_event_handler, start_link, [on_procurement_initiated_initiate_sale, #{}]},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, Children}}.
