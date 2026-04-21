%%% @doc Publish `<realm>.git.<repo_id>.ref_updated_v1` FACTs.
%%%
%%% The socket listener parses post-receive hook lines and hands the
%%% tuple `{RepoId, OldSha, NewSha, RefName}` to this worker via a
%%% cast. We hand it off to `hecate_mesh_client:publish/2`.
%%%
%%% If the mesh isn't activated the publish returns
%%% `{error, not_activated}` and we log a debug line — no retries in
%%% the walking skeleton. A later revision may queue pending facts
%%% for replay on activation.
%%% @end
-module(publish_ref_updated_fact).
-behaviour(gen_server).

-export([start_link/0, publish/4]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-spec start_link() -> {ok, pid()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec publish(binary(), binary(), binary(), binary()) -> ok.
publish(RepoId, OldSha, NewSha, RefName)
  when is_binary(RepoId), is_binary(OldSha),
       is_binary(NewSha), is_binary(RefName) ->
    gen_server:cast(?MODULE, {publish, RepoId, OldSha, NewSha, RefName}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) -> {ok, #{}}.

handle_call(_Msg, _From, State) -> {reply, ok, State}.

handle_cast({publish, RepoId, OldSha, NewSha, RefName}, State) ->
    Realm = hecate_topics:realm(),
    Topic = <<Realm/binary, ".git.", RepoId/binary, ".ref_updated_v1">>,
    Payload = #{
        repo_id   => RepoId,
        ref       => RefName,
        old_sha   => OldSha,
        new_sha   => NewSha,
        timestamp => erlang:system_time(second)
    },
    case hecate_mesh_client:publish(Topic, Payload) of
        ok ->
            logger:info("[publish_ref_updated_fact] Published ~s (ref=~s)",
                        [Topic, RefName]);
        {error, not_activated} ->
            logger:debug("[publish_ref_updated_fact] Mesh dormant — skipped ~s",
                         [Topic]);
        {error, Reason} ->
            logger:warning("[publish_ref_updated_fact] Publish ~s failed: ~p",
                           [Topic, Reason])
    end,
    {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) -> {noreply, State}.

terminate(_Reason, _State) -> ok.
