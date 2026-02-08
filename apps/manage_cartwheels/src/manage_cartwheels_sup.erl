%%% @doc manage_cartwheels top-level supervisor
%%%
%%% Starts this domain's ReckonDB store.
%%% No emitters - Cartwheel is internal lifecycle tracking.
%%%
%%% Supervises:
%%% - initiate_cartwheel_spoke_sup: Contains the listener and policy for
%%%   cartwheel initiation triggered by cartwheel_identified facts.
%%%
%%% @end
-module(manage_cartwheels_sup).
-behaviour(supervisor).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start_link/0, init/1]).

%% Suppress dialyzer warnings for calls to reckon_db_sup (excluded from PLT)
-dialyzer({nowarn_function, [init/1]}).

-define(STORE_ID, manage_cartwheels_store).
-define(DATA_DIR, "data/reckon/manage_cartwheels").

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
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
            id => initiate_cartwheel_spoke_sup,
            start => {initiate_cartwheel_spoke_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],

    {ok, {SupFlags, Children}}.
