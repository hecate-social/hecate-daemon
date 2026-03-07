%%% @doc project_llm_mentorships top-level supervisor
-module(project_llm_mentorships_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% Hybrid store: ETS tables + SQLite for remote tables
        {project_llm_mentorships_store,
            {project_llm_mentorships_store, start_link, []},
            permanent, 5000, worker, [project_llm_mentorships_store]},

        %% ETS-backed evoq_projection modules
        #{id => learning_submitted_v1_to_learnings,
          start => {evoq_projection, start_link, [learning_submitted_v1_to_learnings, #{}]},
          restart => permanent, type => worker},
        #{id => learning_validated_v1_to_learnings,
          start => {evoq_projection, start_link, [learning_validated_v1_to_learnings, #{}]},
          restart => permanent, type => worker},
        #{id => learning_rejected_v1_to_learnings,
          start => {evoq_projection, start_link, [learning_rejected_v1_to_learnings, #{}]},
          restart => permanent, type => worker},
        #{id => learning_endorsed_v1_to_learnings,
          start => {evoq_projection, start_link, [learning_endorsed_v1_to_learnings, #{}]},
          restart => permanent, type => worker},
        #{id => learning_disputed_v1_to_learnings,
          start => {evoq_projection, start_link, [learning_disputed_v1_to_learnings, #{}]},
          restart => permanent, type => worker},
        #{id => learning_dispute_resolved_v1_to_learnings,
          start => {evoq_projection, start_link, [learning_dispute_resolved_v1_to_learnings, #{}]},
          restart => permanent, type => worker},
        #{id => mentor_subscribed_v1_to_subscriptions,
          start => {evoq_projection, start_link, [mentor_subscribed_v1_to_subscriptions, #{}]},
          restart => permanent, type => worker},
        #{id => mentor_unsubscribed_v1_to_subscriptions,
          start => {evoq_projection, start_link, [mentor_unsubscribed_v1_to_subscriptions, #{}]},
          restart => permanent, type => worker},
        #{id => expertise_declared_v1_to_profiles,
          start => {evoq_projection, start_link, [expertise_declared_v1_to_profiles, #{}]},
          restart => permanent, type => worker},
        #{id => expertise_withdrawn_v1_to_profiles,
          start => {evoq_projection, start_link, [expertise_withdrawn_v1_to_profiles, #{}]},
          restart => permanent, type => worker},

        %% Listener desks for remote facts from mesh (still SQLite-backed)
        {remote_learning_listener_sup,
            {remote_learning_listener_sup, start_link, []},
            permanent, infinity, supervisor, [remote_learning_listener_sup]},
        {mentor_discovery_listener_sup,
            {mentor_discovery_listener_sup, start_link, []},
            permanent, infinity, supervisor, [mentor_discovery_listener_sup]}
    ],
    {ok, {{one_for_one, 10, 10}, Children}}.
