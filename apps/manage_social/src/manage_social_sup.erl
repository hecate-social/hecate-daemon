%%% @doc manage_social top-level supervisor
%%%
%%% Starts this domain's ReckonDB store and supervises emitters/listeners.
%%% VERTICAL SLICING: This domain owns its own event store.
-module(manage_social_sup).
-behaviour(supervisor).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start_link/0, init/1]).

%% Suppress dialyzer warnings for calls to reckon_db_sup (excluded from PLT)
-dialyzer({nowarn_function, [init/1]}).

-define(STORE_ID, manage_social_store).
-define(DATA_DIR, "data/reckon/social").

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    %% Start this domain's ReckonDB store
    StoreConfig = #store_config{
        store_id = ?STORE_ID,
        data_dir = ?DATA_DIR,
        mode = single,
        writer_pool_size = 5,
        reader_pool_size = 5,
        gateway_pool_size = 1,
        options = #{}
    },
    case reckon_db_sup:start_store(StoreConfig) of
        {ok, _Pid} ->
            logger:info("Started store ~p", [?STORE_ID]);
        {error, {already_started, _Pid}} ->
            logger:info("Store ~p already running", [?STORE_ID]);
        {error, Reason} ->
            logger:error("Failed to start store ~p: ~p", [?STORE_ID, Reason]),
            exit({failed_to_start_store, ?STORE_ID, Reason})
    end,

    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    Children = [
        %% Emitters: publish domain events to mesh as integration facts
        {agent_followed_v1_to_mesh,
            {agent_followed_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [agent_followed_v1_to_mesh]},
        {agent_unfollowed_v1_to_mesh,
            {agent_unfollowed_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [agent_unfollowed_v1_to_mesh]},
        {capability_endorsed_v1_to_mesh,
            {capability_endorsed_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [capability_endorsed_v1_to_mesh]},
        {endorsement_revoked_v1_to_mesh,
            {endorsement_revoked_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [endorsement_revoked_v1_to_mesh]},

        %% Listener spokes: receive mesh facts, dispatch commands (filtered by MY_IDENTITIES)
        {follower_events_listener_sup,
            {follower_events_listener_sup, start_link, []},
            permanent, infinity, supervisor, [follower_events_listener_sup]},
        {endorsement_events_listener_sup,
            {endorsement_events_listener_sup, start_link, []},
            permanent, infinity, supervisor, [endorsement_events_listener_sup]}
    ],

    {ok, {SupFlags, Children}}.
