%%% @doc manage_torches top-level supervisor
%%%
%%% Starts this domain's ReckonDB store and supervises:
%%% - torch_initiated_v1_to_mesh: Emitter that publishes torch initiation facts
%%% - cartwheel_identified_v1_to_mesh: Emitter that publishes cartwheel identification facts
%%%
%%% @end
-module(manage_torches_sup).
-behaviour(supervisor).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start_link/0]).
-export([init/1]).

%% Suppress dialyzer warnings for calls to reckon_db_sup (excluded from PLT)
-dialyzer({nowarn_function, [init/1]}).

-define(STORE_ID, manage_torches_store).
-define(DATA_DIR, "data/reckon/manage_torches").

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    %% Start the ReckonDB store for this domain
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
        #{
            id => torch_initiated_v1_to_mesh,
            start => {torch_initiated_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        },
        #{
            id => cartwheel_identified_v1_to_mesh,
            start => {cartwheel_identified_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        }
    ],

    {ok, {SupFlags, Children}}.
