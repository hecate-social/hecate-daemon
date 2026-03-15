%%% @doc guide_procurement_lifecycle top-level supervisor
%%%
%%% Supervises PG emitters for procurement lifecycle events.
%%% @end
-module(guide_procurement_lifecycle_sup).
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
        emitter(procurement_initiated_v1_to_pg),
        emitter(procurement_archived_v1_to_pg),

        %% -- Cross-context process managers --
        emitter(on_offering_terms_accepted_initiate_procurement)
    ],

    {ok, {SupFlags, Children}}.

emitter(Mod) ->
    #{id => Mod, start => {evoq_event_handler, start_link, [Mod, #{}]},
      restart => permanent, type => worker}.
