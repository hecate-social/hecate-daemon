%%% @doc Desk: create a bare git repository on disk when a repo
%%% is initiated.
%%%
%%% Subscribes to `repo_initiated_v1` via the `evoq_event_handler`
%%% behaviour. On each event, runs `git init --bare` in the path
%%% resolved via `repo_paths:repo_dir/1` and installs the
%%% post-receive hook that fires the `ref_updated_v1` FACT.
%%%
%%% Idempotent — re-emitting the event is a no-op beyond hook
%%% refresh.
%%% @end
-module(initialize_repo_on_disk).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"repo_initiated_v1">>].

init(_Config) ->
    {ok, #{}}.

handle_event(<<"repo_initiated_v1">>, Event, _Metadata, State) ->
    RepoId        = gf(repo_id, Event),
    DefaultBranch = gf(default_branch, Event, <<"main">>),
    case RepoId of
        undefined ->
            logger:warning("[initialize_repo_on_disk] repo_initiated_v1 missing repo_id: ~p",
                           [Event]),
            {ok, State};
        _ ->
            RepoDir = repo_paths:repo_dir(RepoId),
            case git_init_cmd:run(unicode:characters_to_list(RepoDir),
                                  DefaultBranch, RepoId) of
                {ok, created} ->
                    logger:info("[initialize_repo_on_disk] Created bare repo ~s at ~s",
                                [RepoId, RepoDir]);
                {ok, exists} ->
                    logger:info("[initialize_repo_on_disk] Repo ~s already on disk at ~s (hook refreshed)",
                                [RepoId, RepoDir]);
                {error, no_git} ->
                    logger:error("[initialize_repo_on_disk] git binary not found — "
                                 "bare repo ~s NOT created", [RepoId]);
                {error, Reason} ->
                    logger:error("[initialize_repo_on_disk] Failed to init ~s: ~p",
                                 [RepoId, Reason])
            end,
            {ok, State}
    end;
handle_event(_OtherType, _Event, _Metadata, State) ->
    {ok, State}.

%%====================================================================
%% Internal
%%====================================================================

gf(Key, Map) -> gf(Key, Map, undefined).
gf(Key, Map, Default) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            BinKey = atom_to_binary(Key, utf8),
            maps:get(BinKey, Map, Default)
    end.
