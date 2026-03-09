%%% @doc guide_payment_lifecycle top-level supervisor
%%%
%%% Supervises PG emitters for payment lifecycle:
%%% - payment_initiated_v1_to_pg
%%% - payment_archived_v1_to_pg
%%% @end
-module(guide_payment_lifecycle_sup).
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
        %% -- PG emitters (internal, subscribe via evoq -> broadcast to pg) --

        #{id => payment_initiated_v1_to_pg,
          start => {evoq_event_handler, start_link, [payment_initiated_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => payment_archived_v1_to_pg,
          start => {evoq_event_handler, start_link, [payment_archived_v1_to_pg, #{}]},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, Children}}.
