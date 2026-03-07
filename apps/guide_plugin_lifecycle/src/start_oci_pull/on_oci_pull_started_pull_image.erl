%%% @doc Process Manager: On OCI pull started, pull the OCI image.
%%%
%%% Subscribes to oci_pull_started_v1 events from plugins_store.
%%% Runs `podman pull` via shared_podman, tracks progress in ETS,
%%% provisions .container file, and dispatches complete_oci_pull_v1.
%%%
%%% Also listens for cancel events via pg to kill in-progress pulls.
%%% On startup, reconciles plugins stuck in PULLING state.
%%% @end
-module(on_oci_pull_started_pull_image).
-behaviour(gen_server).

-include_lib("evoq/include/evoq_types.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(EVENT_TYPE, <<"oci_pull_started_v1">>).
-define(SUB_NAME, <<"on_oci_pull_started_pull_image">>).
-define(STORE_ID, plugins_store).
-define(ETS_TABLE, plugin_pull_progress).
-define(CANCEL_GROUP, {oci_pull_cancelled_v1, node}).
-define(RECONCILE_DELAY_MS, 8000).

-record(state, {
    pulls :: #{binary() => pid()}
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ets:new(?ETS_TABLE, [public, named_table, set, {read_concurrency, true}]),
    {ok, _} = evoq_subscriptions:subscribe(
        ?STORE_ID, event_type, ?EVENT_TYPE, ?SUB_NAME,
        #{subscriber_pid => self()}),
    ensure_pg_scope(),
    pg:join(pg, ?CANCEL_GROUP, self()),
    erlang:send_after(?RECONCILE_DELAY_MS, self(), reconcile),
    {ok, #state{pulls = #{}}}.

handle_info({events, Events}, State) ->
    NewState = lists:foldl(fun handle_event/2, State, Events),
    {noreply, NewState};

handle_info({?CANCEL_GROUP, #evoq_event{data = Data}}, #state{pulls = Pulls} = State) ->
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

handle_info(reconcile, State) ->
    NewState = reconcile_pulling_plugins(State),
    {noreply, NewState};

handle_info({'DOWN', _Ref, process, Pid, _Reason}, #state{pulls = Pulls} = State) ->
    Remaining = maps:filter(fun(_, P) -> P =/= Pid end, Pulls),
    {noreply, State#state{pulls = Remaining}};

handle_info(_Info, State) ->
    {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

%% Internal

handle_event(#evoq_event{data = Data}, #state{pulls = Pulls} = State) ->
    PluginId = get_value(plugin_id, Data),
    OciImage = get_value(oci_image, Data),
    case maps:is_key(PluginId, Pulls) of
        true ->
            logger:warning("[pull-pm] Already pulling ~s, ignoring", [PluginId]),
            State;
        false ->
            start_pull(PluginId, OciImage, State)
    end.

start_pull(PluginId, OciImage, #state{pulls = Pulls} = State) ->
    case resolve_oci_image(PluginId, OciImage) of
        undefined ->
            logger:error("[pull-pm] No OCI image for ~s", [PluginId]),
            State;
        Image ->
            DaemonName = shared_podman:extract_daemon_name(Image),
            LatestImage = <<(shared_podman:strip_tag(Image))/binary, ":latest">>,
            provision_container(PluginId, DaemonName, Image),
            Self = self(),
            Pid = spawn_link(fun() ->
                ets:insert(?ETS_TABLE, {PluginId, #{status => downloading, percent => 0}}),
                shared_podman:pull_image(LatestImage, self()),
                pull_relay(Self, PluginId)
            end),
            monitor(process, Pid),
            State#state{pulls = maps:put(PluginId, Pid, Pulls)}
    end.

pull_relay(Parent, PluginId) ->
    receive
        {pull_progress, Progress} ->
            Parent ! {pull_progress, PluginId, Progress},
            pull_relay(Parent, PluginId);
        {pull_done, Result} ->
            Parent ! {pull_done, PluginId, Result}
    end.

provision_container(PluginId, DaemonName, OciImage) ->
    AppsDir = shared_paths:gitops_apps_dir(),
    ok = filelib:ensure_path(AppsDir),
    FilePath = filename:join(AppsDir, shared_podman:container_filename(DaemonName)),
    case filelib:is_regular(FilePath) of
        true -> ok;
        false ->
            PluginDataDir = filename:join(shared_paths:hecate_home(), DaemonName),
            ok = filelib:ensure_path(PluginDataDir),
            Content = shared_podman:render_container(DaemonName, OciImage),
            case file:write_file(FilePath, Content) of
                ok ->
                    logger:info("[pull-pm] Provisioned .container for ~s", [PluginId]);
                {error, Reason} ->
                    logger:error("[pull-pm] Failed to write .container for ~s: ~p",
                                 [PluginId, Reason])
            end
    end.

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

resolve_oci_image(_PluginId, OciImage) when is_binary(OciImage), byte_size(OciImage) > 0 ->
    OciImage;
resolve_oci_image(PluginId, _) ->
    case project_plugins_store:get(PluginId) of
        {ok, #{oci_image := Image}} -> Image;
        _ -> undefined
    end.

reconcile_pulling_plugins(State) ->
    try project_plugins_store:list_by_status(64) of
        {ok, Plugins} ->
            lists:foldl(fun(#{plugin_id := PId, oci_image := Img, status := S}, Acc) ->
                case S band 2 =:= 0 andalso not maps:is_key(PId, Acc#state.pulls) of
                    true ->
                        logger:info("[pull-pm] Reconciling stale pull for ~s", [PId]),
                        start_pull(PId, Img, Acc);
                    false ->
                        Acc
                end
            end, State, Plugins);
        {error, _} ->
            State
    catch
        error:badarg -> State
    end.

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
