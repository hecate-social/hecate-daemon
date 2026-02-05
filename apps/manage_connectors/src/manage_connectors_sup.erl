%%% @doc manage_connectors top-level supervisor
%%%
%%% Starts this domain's ReckonDB store, cleans up stale sockets,
%%% and supervises the process manager for connector lifecycle.
%%% VERTICAL SLICING: This domain owns its own event store.
-module(manage_connectors_sup).
-behaviour(supervisor).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start_link/0, init/1]).

%% Suppress dialyzer warnings for calls to reckon_db_sup (excluded from PLT)
-dialyzer({nowarn_function, [init/1]}).

-define(STORE_ID, manage_connectors_store).
-define(DATA_DIR, "data/reckon/connectors").

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    %% Clean up stale socket files from previous daemon crashes
    cleanup_stale_sockets(),

    %% Start this domain's ReckonDB store
    StoreConfig = #store_config{
        store_id = ?STORE_ID,
        data_dir = ?DATA_DIR,
        mode = single,
        writer_pool_size = 2,
        reader_pool_size = 2,
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
        %% Process Manager: starts/stops Cowboy listeners on connector events
        {on_connector_registered_start_listener,
            {on_connector_registered_start_listener, start_link, []},
            permanent, 5000, worker, [on_connector_registered_start_listener]}
    ],

    {ok, {SupFlags, Children}}.

%% @private Clean up stale .sock files from previous daemon crashes.
%% Unix domain sockets survive process death; must be removed before rebind.
cleanup_stale_sockets() ->
    ConnectorsDir = connectors_dir(),
    case filelib:is_dir(ConnectorsDir) of
        true ->
            Pattern = filename:join(ConnectorsDir, "*.sock"),
            Sockets = filelib:wildcard(binary_to_list(Pattern)),
            lists:foreach(fun(SocketPath) ->
                logger:info("Cleaning stale socket: ~s", [SocketPath]),
                file:delete(SocketPath)
            end, Sockets);
        false ->
            ok
    end.

%% @private Get the connectors directory path.
connectors_dir() ->
    Default = filename:join([os:getenv("HOME"), ".config", "hecate", "connectors"]),
    application:get_env(manage_connectors, connectors_dir, list_to_binary(Default)).
