%%% @doc Process Manager: On OCI pull started, pull the OCI image.
%%%
%%% Subscribes to oci_pull_started_v1 events via pg group (internal).
%%% Runs `podman pull` via shared_podman, tracks progress in ETS,
%%% provisions .container file, and dispatches complete_oci_pull_v1.
%%%
%%% Also listens for cancel events via pg to kill in-progress pulls.
%%%
%%% This PM is a gen_server (not evoq_event_handler) because it needs
%%% handle_info for pull worker progress, completion, and monitor messages.
%%% Events arrive via pg groups, which are fed by the orthodox
%%% evoq_event_handler emitters (oci_pull_started_v1_to_pg,
%%% oci_pull_cancelled_v1_to_pg).
-module(on_oci_pull_started_pull_image).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(ETS_TABLE, plugin_pull_progress).
-define(PULL_GROUP, {oci_pull_started_v1, node}).
-define(CANCEL_GROUP, {oci_pull_cancelled_v1, node}).

-record(state, {
    pulls :: #{binary() => pid()}
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ets:new(?ETS_TABLE, [public, named_table, set, {read_concurrency, true}]),
    ensure_pg_scope(),
    pg:join(pg, ?PULL_GROUP, self()),
    pg:join(pg, ?CANCEL_GROUP, self()),
    {ok, #state{pulls = #{}}}.

%% -- Event delivery via pg groups --

handle_info({?PULL_GROUP, Event}, State) ->
    Data = maps:get(data, Event),
    PluginId = get_value(plugin_id, Data),
    OciImage = get_value(oci_image, Data),
    case maps:is_key(PluginId, State#state.pulls) of
        true ->
            logger:warning("[pull-pm] Already pulling ~s, ignoring", [PluginId]),
            {noreply, State};
        false ->
            {noreply, start_pull(PluginId, OciImage, State)}
    end;

handle_info({?CANCEL_GROUP, Event}, #state{pulls = Pulls} = State) ->
    Data = maps:get(data, Event),
    PluginId = get_value(plugin_id, Data),
    case maps:find(PluginId, Pulls) of
        {ok, Pid} ->
            exit(Pid, cancelled),
            ets:delete(?ETS_TABLE, PluginId),
            logger:info("[pull-pm] Cancelled pull for ~s", [PluginId]),
            {noreply, State#state{pulls = maps:remove(PluginId, Pulls)}};
        error ->
            {noreply, State}
    end;

%% -- Pull worker messages --

handle_info({pull_progress, PluginId, Progress}, State) ->
    ets:insert(?ETS_TABLE, {PluginId, Progress}),
    {noreply, State};

handle_info({pull_done, PluginId, ok}, #state{pulls = Pulls} = State) ->
    ets:insert(?ETS_TABLE, {PluginId, #{status => complete, percent => 100}}),
    dispatch_complete(PluginId),
    {noreply, State#state{pulls = maps:remove(PluginId, Pulls)}};

handle_info({pull_done, PluginId, {error, Reason}}, #state{pulls = Pulls} = State) ->
    logger:error("[pull-pm] Pull failed for ~s: ~p", [PluginId, Reason]),
    ets:insert(?ETS_TABLE, {PluginId, #{status => error, reason => Reason}}),
    {noreply, State#state{pulls = maps:remove(PluginId, Pulls)}};

handle_info({'DOWN', _Ref, process, Pid, _Reason}, #state{pulls = Pulls} = State) ->
    Remaining = maps:filter(fun(_, P) -> P =/= Pid end, Pulls),
    {noreply, State#state{pulls = Remaining}};

handle_info(_Info, State) ->
    {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

%% -- Pull orchestration --

start_pull(_PluginId, undefined, State) ->
    logger:error("[pull-pm] No OCI image in event, cannot pull"),
    State;
start_pull(PluginId, OciImage, #state{pulls = Pulls} = State) ->
    DaemonName = shared_podman:extract_daemon_name(OciImage),
    LatestImage = <<(shared_podman:strip_tag(OciImage))/binary, ":latest">>,
    provision_container(PluginId, DaemonName, OciImage),
    Self = self(),
    Pid = spawn_link(fun() ->
        ets:insert(?ETS_TABLE, {PluginId, #{status => downloading, percent => 0}}),
        shared_podman:pull_image(LatestImage, self()),
        pull_relay(Self, PluginId)
    end),
    monitor(process, Pid),
    State#state{pulls = maps:put(PluginId, Pid, Pulls)}.

pull_relay(Parent, PluginId) ->
    receive
        {pull_progress, Progress} ->
            Parent ! {pull_progress, PluginId, Progress},
            pull_relay(Parent, PluginId);
        {pull_done, Result} ->
            Parent ! {pull_done, PluginId, Result}
    end.

%% -- Container provisioning --

provision_container(PluginId, DaemonName, OciImage) ->
    AppsDir = shared_paths:gitops_apps_dir(),
    ok = filelib:ensure_path(AppsDir),
    Filename = shared_podman:container_filename(DaemonName),
    FilePath = filename:join(AppsDir, Filename),
    case filelib:is_regular(FilePath) of
        true ->
            ensure_quadlet_symlink(FilePath, Filename, PluginId);
        false ->
            PluginDataDir = filename:join(shared_paths:hecate_home(), DaemonName),
            ok = filelib:ensure_path(PluginDataDir),
            Content = shared_podman:render_container(DaemonName, OciImage),
            case file:write_file(FilePath, Content) of
                ok ->
                    logger:info("[pull-pm] Provisioned .container for ~s", [PluginId]),
                    ensure_quadlet_symlink(FilePath, Filename, PluginId);
                {error, Reason} ->
                    logger:error("[pull-pm] Failed to write .container for ~s: ~p",
                                 [PluginId, Reason])
            end
    end.

ensure_quadlet_symlink(FilePath, Filename, PluginId) ->
    QuadletDir = filename:join([os:getenv("HOME"), ".config", "containers", "systemd"]),
    ok = filelib:ensure_path(QuadletDir),
    LinkPath = filename:join(QuadletDir, Filename),
    _ = file:delete(LinkPath),
    case file:make_symlink(FilePath, LinkPath) of
        ok ->
            logger:info("[pull-pm] Symlinked Quadlet for ~s: ~s -> ~s",
                        [PluginId, LinkPath, FilePath]);
        {error, Reason} ->
            logger:error("[pull-pm] Failed to symlink Quadlet for ~s: ~p",
                         [PluginId, Reason])
    end.

%% -- Command dispatch --

dispatch_complete(PluginId) ->
    case complete_oci_pull_v1:new(#{plugin_id => PluginId}) of
        {ok, Cmd} ->
            case maybe_complete_oci_pull:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[pull-pm] Pull completed for ~s", [PluginId]);
                {error, Reason} ->
                    logger:error("[pull-pm] Failed to dispatch complete for ~s: ~p",
                                 [PluginId, Reason])
            end;
        {error, Reason} ->
            logger:error("[pull-pm] Invalid complete command for ~s: ~p", [PluginId, Reason])
    end.

%% -- Helpers --

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.

ensure_pg_scope() ->
    case pg:start(pg) of
        {ok, _Pid} -> ok;
        {error, {already_started, _Pid}} -> ok
    end.
