%%%-------------------------------------------------------------------
%%% @doc In-VM plugin loader.
%%%
%%% Loads plugin packages as OTP applications inside the daemon BEAM VM.
%%% Each plugin gets:
%%%   - Code path added (ebin/)
%%%   - ReckonDB store (if store_config/0 returns one)
%%%   - Cowboy routes mounted under /plugin/{name}/api/...
%%%   - Static assets served at /plugin/{name}/...
%%%   - Supervision tree started
%%%
%%% Plugin packages are .tar.gz archives containing:
%%%   ebin/           - compiled .beam files
%%%   priv/static/    - frontend assets (optional)
%%%   manifest.json   - plugin metadata
%%%
%%% Extracted to: ~/.hecate/plugins/{name}/
%%%
%%% The loader maintains an ETS table of loaded plugins for route
%%% hot-swapping and status queries.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_plugin_loader).
-behaviour(gen_server).

-include_lib("hecate_sdk/include/hecate_plugin.hrl").
-include_lib("reckon_db/include/reckon_db.hrl").

-export([start_link/0]).
-export([load_plugin/2, unload_plugin/1, reload_plugin/2]).
-export([loaded_plugins/0, plugin_routes/0, plugin_static_routes/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(SERVER, ?MODULE).
-define(TABLE, hecate_loaded_plugins).
-define(PLUGINS_DIR, "plugins").

-record(loaded_plugin, {
    name        :: binary(),
    callback    :: module(),
    version     :: binary(),
    routes      :: [tuple()],
    static_dir  :: file:filename() | none,
    store_id    :: atom() | none,
    sup_pid     :: pid() | undefined,
    loaded_at   :: integer()
}).

%%====================================================================
%% Public API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%% @doc Load a plugin into the VM.
%% PluginName is the directory name (e.g., <<"scribe">>).
%% CallbackModule is the module implementing hecate_plugin behaviour.
-spec load_plugin(binary(), module()) -> ok | {error, term()}.
load_plugin(PluginName, CallbackModule) ->
    gen_server:call(?SERVER, {load, PluginName, CallbackModule}, 30000).

%% @doc Unload a plugin from the VM.
-spec unload_plugin(binary()) -> ok | {error, term()}.
unload_plugin(PluginName) ->
    gen_server:call(?SERVER, {unload, PluginName}, 30000).

%% @doc Reload a plugin (unload + load).
-spec reload_plugin(binary(), module()) -> ok | {error, term()}.
reload_plugin(PluginName, CallbackModule) ->
    gen_server:call(?SERVER, {reload, PluginName, CallbackModule}, 30000).

%% @doc List all loaded plugins.
-spec loaded_plugins() -> [map()].
loaded_plugins() ->
    case ets:info(?TABLE) of
        undefined -> [];
        _ ->
            ets:foldl(fun(#loaded_plugin{} = P, Acc) ->
                [#{
                    name => P#loaded_plugin.name,
                    callback => P#loaded_plugin.callback,
                    version => P#loaded_plugin.version,
                    store_id => P#loaded_plugin.store_id,
                    has_frontend => P#loaded_plugin.static_dir =/= none,
                    loaded_at => P#loaded_plugin.loaded_at
                } | Acc]
            end, [], ?TABLE)
    end.

%% @doc Collect API routes from all loaded plugins (for cowboy dispatch).
-spec plugin_routes() -> [cowboy_router:route_match()].
plugin_routes() ->
    case ets:info(?TABLE) of
        undefined -> [];
        _ ->
            ets:foldl(fun(#loaded_plugin{name = Name, callback = Cb, routes = Routes}, Acc) ->
                Prefix = "/plugin/" ++ binary_to_list(Name) ++ "/api",
                PluginRoutes = [{Prefix ++ Path, Handler, Opts}
                                || {Path, Handler, Opts} <- Routes],
                ManifestRoute = {Prefix ++ "/manifest", hecate_plugin_manifest_handler, #{callback => Cb}},
                FlagMapsRoute = {Prefix ++ "/flag-maps", hecate_plugin_flag_maps_handler, #{callback => Cb}},
                [ManifestRoute, FlagMapsRoute | PluginRoutes] ++ Acc
            end, [], ?TABLE)
    end.

%% @doc Collect static asset routes from all loaded plugins.
-spec plugin_static_routes() -> [cowboy_router:route_match()].
plugin_static_routes() ->
    case ets:info(?TABLE) of
        undefined -> [];
        _ ->
            ets:foldl(fun
                (#loaded_plugin{static_dir = none}, Acc) -> Acc;
                (#loaded_plugin{name = Name, static_dir = Dir}, Acc) ->
                    Prefix = "/plugin/" ++ binary_to_list(Name) ++ "/ui",
                    [
                        {Prefix ++ "/[...]", cowboy_static,
                            {dir, Dir, [{mimetypes, cow_mimetypes, all}]}}
                    | Acc]
            end, [], ?TABLE)
    end.

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    ets:new(?TABLE, [set, named_table, {keypos, #loaded_plugin.name},
                     public, {read_concurrency, true}]),
    logger:info("[plugin-loader] Plugin loader ready"),
    {ok, #{}}.

handle_call({load, PluginName, CallbackModule}, _From, State) ->
    Result = do_load(PluginName, CallbackModule),
    {reply, Result, State};

handle_call({unload, PluginName}, _From, State) ->
    Result = do_unload(PluginName),
    {reply, Result, State};

handle_call({reload, PluginName, CallbackModule}, _From, State) ->
    _ = do_unload(PluginName),
    Result = do_load(PluginName, CallbackModule),
    {reply, Result, State};

handle_call(_Req, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    %% Unload all plugins on shutdown
    case ets:info(?TABLE) of
        undefined -> ok;
        _ ->
            ets:foldl(fun(#loaded_plugin{name = Name}, _) ->
                do_unload(Name)
            end, ok, ?TABLE)
    end,
    ok.

%%====================================================================
%% Internal — Load
%%====================================================================

do_load(RawPluginName, CallbackModule) ->
    PluginName = sanitize_plugin_name(RawPluginName),
    logger:info("[plugin-loader] Loading plugin ~s (callback: ~p)",
                [PluginName, CallbackModule]),
    case ets:lookup(?TABLE, PluginName) of
        [_] ->
            {error, already_loaded};
        [] ->
            try
                load_steps(PluginName, CallbackModule)
            catch
                Class:Reason:Stack ->
                    logger:error("[plugin-loader] Failed to load ~s: ~p:~p~n~p",
                                 [PluginName, Class, Reason, Stack]),
                    %% Clean up partial load
                    cleanup_failed_load(PluginName, CallbackModule),
                    {error, {load_failed, Reason}}
            end
    end.

load_steps(PluginName, CallbackModule) ->
    %% 1. Ensure plugin directories exist
    hecate_plugin_paths:ensure_layout(PluginName),

    %% 2. Add code path and load all .beam files
    %% code:ensure_loaded/1 fails in embedded mode (releases),
    %% so we use code:load_abs/1 which works in any mode.
    EbinDir = plugin_ebin_dir(PluginName),
    case filelib:is_dir(EbinDir) of
        true ->
            true = code:add_pathz(EbinDir),
            load_all_beams(EbinDir),
            logger:info("[plugin-loader] Code path added: ~s", [EbinDir]);
        false ->
            throw({ebin_not_found, EbinDir})
    end,

    %% 3. Verify callback module is now loaded
    case erlang:module_loaded(CallbackModule) of
        true -> ok;
        false -> throw({callback_not_loadable, CallbackModule, not_found_in_ebin})
    end,

    %% 4. Read manifest
    Manifest = CallbackModule:manifest(),
    Version = maps:get(version, Manifest, <<"unknown">>),
    logger:info("[plugin-loader] Plugin ~s v~s", [PluginName, Version]),

    %% 5. Create ReckonDB store if configured
    StoreId = case CallbackModule:store_config() of
        none ->
            logger:info("[plugin-loader] ~s: no event store", [PluginName]),
            none;
        #hecate_store_config{store_id = SId, dir_name = DirName,
                             description = Desc, options = Opts} ->
            create_plugin_store(PluginName, SId, DirName, Desc, Opts),
            SId
    end,

    %% 6. Initialize plugin
    Config = #{
        plugin_name => PluginName,
        store_id => StoreId,
        data_dir => hecate_plugin_paths:base_dir(PluginName)
    },
    {ok, _PluginState} = CallbackModule:init(Config),

    %% 7. Get routes
    Routes = CallbackModule:routes(),

    %% 8. Get static dir
    StaticDir = case CallbackModule:static_dir() of
        none -> none;
        RelDir ->
            AbsDir = filename:join(plugin_base_dir(PluginName), RelDir),
            case filelib:is_dir(AbsDir) of
                true -> AbsDir;
                false ->
                    logger:warning("[plugin-loader] Static dir not found: ~s", [AbsDir]),
                    none
            end
    end,

    %% 9. Start store subscription if plugin has a store
    case StoreId of
        none -> ok;
        _ ->
            case evoq_store_subscription:start_link(StoreId) of
                {ok, _} ->
                    logger:info("[plugin-loader] Store subscription ready for ~p", [StoreId]);
                {error, SubErr} ->
                    logger:warning("[plugin-loader] Store subscription failed for ~p: ~p",
                                   [StoreId, SubErr])
            end
    end,

    %% 10. Register in ETS
    Record = #loaded_plugin{
        name = PluginName,
        callback = CallbackModule,
        version = Version,
        routes = Routes,
        static_dir = StaticDir,
        store_id = StoreId,
        sup_pid = undefined,
        loaded_at = erlang:system_time(millisecond)
    },
    ets:insert(?TABLE, Record),

    %% 11. Hot-swap cowboy dispatch to include new routes
    hot_swap_routes(),

    logger:info("[plugin-loader] Plugin ~s loaded successfully", [PluginName]),
    ok.

%%====================================================================
%% Internal — Unload
%%====================================================================

do_unload(RawPluginName) ->
    PluginName = sanitize_plugin_name(RawPluginName),
    case ets:lookup(?TABLE, PluginName) of
        [] ->
            {error, not_loaded};
        [#loaded_plugin{callback = Mod, store_id = _StoreId}] ->
            logger:info("[plugin-loader] Unloading plugin ~s", [PluginName]),

            %% Remove from ETS first (stops route serving)
            ets:delete(?TABLE, PluginName),

            %% Hot-swap routes to remove plugin's routes
            hot_swap_routes(),

            %% Remove code path
            EbinDir = plugin_ebin_dir(PluginName),
            code:del_path(EbinDir),

            %% Purge callback module
            code:purge(Mod),
            code:delete(Mod),

            logger:info("[plugin-loader] Plugin ~s unloaded", [PluginName]),
            ok
    end.

%%====================================================================
%% Internal — Route hot-swap
%%====================================================================

%% @doc Recompile cowboy dispatch with current plugin routes included.
%% Called after load/unload to update the running listener.
hot_swap_routes() ->
    try
        ApiRoutes = hecate_api_routes:discover_routes(),
        StaticRoutes = hecate_api_static:routes(),
        PluginApiRoutes = plugin_routes(),
        PluginStaticRoutes = plugin_static_routes(),
        SpaFallback = [{'_', hecate_api_spa_fallback, []}],
        AllRoutes = ApiRoutes ++ PluginApiRoutes ++ StaticRoutes ++ PluginStaticRoutes ++ SpaFallback,
        Dispatch = cowboy_router:compile([{'_', AllRoutes}]),
        cowboy:set_env(hecate_socket_listener, dispatch, Dispatch),
        logger:info("[plugin-loader] Routes hot-swapped (~b plugin API, ~b plugin static)",
                     [length(PluginApiRoutes), length(PluginStaticRoutes)])
    catch
        Class:Reason ->
            logger:error("[plugin-loader] Route hot-swap failed: ~p:~p", [Class, Reason])
    end.

%%====================================================================
%% Internal — Paths
%%====================================================================

plugin_base_dir(PluginName) ->
    hecate_plugin_paths:base_dir(PluginName).

plugin_ebin_dir(PluginName) ->
    filename:join(plugin_base_dir(PluginName), "ebin").

%% Strip org prefix from plugin_id (e.g., <<"hecate-apps/hecate-app-scribe">> -> <<"hecate-app-scribe">>)
sanitize_plugin_name(Name) when is_binary(Name) ->
    case binary:split(Name, <<"/">>) of
        [_, Short] -> Short;
        [Single] -> Single
    end;
sanitize_plugin_name(Name) when is_list(Name) ->
    binary_to_list(sanitize_plugin_name(list_to_binary(Name))).

%%====================================================================
%% Internal — Plugin store creation
%%====================================================================

%% Inline version of hecate_plugin_store:create_store/2 to avoid
%% SDK module loading issues in embedded mode.
create_plugin_store(PluginName, StoreId, DirName, Desc, _Opts) ->
    DataDir = hecate_plugin_paths:reckon_path(PluginName, DirName),
    ok = filelib:ensure_path(DataDir),
    logger:info("[plugin-loader] Creating ~s store at ~s (~s)", [StoreId, DataDir, Desc]),
    Config = #store_config{
        store_id = StoreId,
        data_dir = DataDir,
        mode = single,
        writer_pool_size = 5,
        reader_pool_size = 5,
        gateway_pool_size = 2,
        options = #{}
    },
    case reckon_db_sup:start_store(Config) of
        {ok, Pid} ->
            logger:info("[plugin-loader] Store ~p started (~p)", [StoreId, Pid]),
            ok;
        {error, {already_started, Pid}} ->
            logger:info("[plugin-loader] Store ~p already running (~p)", [StoreId, Pid]),
            ok;
        {error, Reason} ->
            throw({store_creation_failed, StoreId, Reason})
    end.

%%====================================================================
%% Internal — Module loading
%%====================================================================

%% @doc Load all .beam files from a directory using code:load_abs/1.
%% Works in both interactive and embedded code server modes.
load_all_beams(EbinDir) ->
    Beams = filelib:wildcard(filename:join(EbinDir, "*.beam")),
    lists:foreach(fun load_beam/1, Beams),
    logger:info("[plugin-loader] Loaded ~b modules from ~s", [length(Beams), EbinDir]).

load_beam(BeamPath) ->
    ModName = list_to_atom(filename:basename(BeamPath, ".beam")),
    case code:load_abs(filename:rootname(BeamPath)) of
        {module, ModName} -> ok;
        {error, Reason} ->
            logger:warning("[plugin-loader] Failed to load ~s: ~p", [BeamPath, Reason])
    end.

%%====================================================================
%% Internal — Cleanup
%%====================================================================

cleanup_failed_load(PluginName, CallbackModule) ->
    ets:delete(?TABLE, PluginName),
    EbinDir = plugin_ebin_dir(PluginName),
    code:del_path(EbinDir),
    code:purge(CallbackModule),
    code:delete(CallbackModule),
    ok.
