%%% @doc Desk: advertise a mesh RPC procedure per initiated repo.
%%%
%%% Procedure URI:
%%%   `{Realm}.git.{RepoId}.rpc`
%%%
%%% The handler function dispatches on the `op` arg (`describe` /
%%% `fetch` / `push`) — see `git_over_mesh_procedure:handle/2`.
%%%
%%% We run as a plain `evoq_event_handler` that:
%%%   - Reacts to `repo_initiated_v1` by calling
%%%     `hecate_mesh_client:register_advertisement/2`.
%%%   - Reacts to `repo_archived_v1` by calling
%%%     `hecate_mesh_client:unregister_advertisement/1`.
%%%
%%% Dedup: a private ETS set (`?MODULE`) tracks advertised procedures
%%% so redundant `repo_initiated_v1` events (e.g. projection replay)
%%% don't double-register.
%%% @end
-module(advertise_repo_procedures).
-behaviour(evoq_event_handler).

-export([start_link/0]).
-export([interested_in/0, init/1, handle_event/4]).

-define(TABLE, ?MODULE).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    %% Create (or reuse) the dedup table before the handler worker starts.
    case ets:info(?TABLE) of
        undefined ->
            ets:new(?TABLE, [named_table, public, set,
                             {read_concurrency, true}]);
        _ ->
            ok
    end,
    evoq_event_handler:start_link(?MODULE, #{}).

interested_in() ->
    [<<"repo_initiated_v1">>, <<"repo_archived_v1">>].

init(_Config) ->
    {ok, #{}}.

handle_event(<<"repo_initiated_v1">>, Event, _Metadata, State) ->
    Data   = maps:get(data, Event, Event),
    RepoId = gf(repo_id, Data),
    Realm  = gf(realm,   Data, hecate_topics:realm()),
    advertise_once(RepoId, Realm),
    {ok, State};
handle_event(<<"repo_archived_v1">>, Event, _Metadata, State) ->
    Data   = maps:get(data, Event, Event),
    RepoId = gf(repo_id, Data),
    retract(RepoId),
    {ok, State};
handle_event(_Other, _Event, _Meta, State) ->
    {ok, State}.

%%====================================================================
%% Internal
%%====================================================================

advertise_once(undefined, _Realm) ->
    logger:warning("[advertise_repo_procedures] missing repo_id, skipping advertise");
advertise_once(RepoId, Realm) ->
    Proc       = procedure_uri(Realm, RepoId),
    StreamProc = stream_procedure_uri(Realm, RepoId),
    case ets:lookup(?TABLE, RepoId) of
        [{_, _Existing}] ->
            logger:debug("[advertise_repo_procedures] ~s already advertised", [Proc]);
        [] ->
            Handler = make_handler(RepoId),
            ok = hecate_mesh_client:register_advertisement(Proc, Handler),
            %% Streaming sibling — server-stream variant of fetch.
            %% Phase 4 pilot 3 of PLAN_MACULA_STREAMING.md.
            StreamHandler = make_stream_handler(RepoId),
            ok = hecate_mesh_client:register_stream_advertisement(
                   StreamProc, server_stream, StreamHandler),
            true = ets:insert(?TABLE, {RepoId, {Proc, StreamProc}}),
            logger:info("[advertise_repo_procedures] Advertised ~s + ~s",
                        [Proc, StreamProc])
    end.

retract(undefined) ->
    ok;
retract(RepoId) ->
    case ets:lookup(?TABLE, RepoId) of
        [{_, {Proc, StreamProc}}] ->
            _ = hecate_mesh_client:unregister_advertisement(Proc),
            _ = hecate_mesh_client:unregister_advertisement(StreamProc),
            ets:delete(?TABLE, RepoId),
            logger:info("[advertise_repo_procedures] Retracted ~s + ~s",
                        [Proc, StreamProc]),
            ok;
        [{_, Proc}] when is_binary(Proc) ->
            %% Backward-compat: legacy single-proc rows from before the
            %% stream pilot landed. Retract just the unary one.
            _ = hecate_mesh_client:unregister_advertisement(Proc),
            ets:delete(?TABLE, RepoId),
            ok;
        [] ->
            ok
    end.

-spec procedure_uri(binary(), binary()) -> binary().
procedure_uri(Realm, RepoId) ->
    <<Realm/binary, ".git.", RepoId/binary, ".rpc">>.

-spec stream_procedure_uri(binary(), binary()) -> binary().
stream_procedure_uri(Realm, RepoId) ->
    <<Realm/binary, ".git.", RepoId/binary, ".rpc_stream">>.

make_handler(RepoId) ->
    %% macula SDK requires handlers to return {ok, Result} | {error, Reason}.
    %% git_over_mesh_procedure:handle/2 returns a bare map (with its own
    %% ok/error keys); wrap the success path so the V2 pool's
    %% station_link can encode the RESULT frame. If the handler crashes
    %% the SDK catches and translates to a BOLT#4 error — nothing to do
    %% here.
    fun(Args) -> {ok, git_over_mesh_procedure:handle(RepoId, Args)} end.

make_stream_handler(RepoId) ->
    fun(Stream, Args) ->
        git_over_mesh_stream_procedure:handle(RepoId, Stream, Args)
    end.

gf(Key, Map)          -> gf(Key, Map, undefined).
gf(Key, Map, Default) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            BinKey = atom_to_binary(Key, utf8),
            maps:get(BinKey, Map, Default)
    end.
