%%% @doc Query facade for the repos ETS read model.
%%%
%%% Owns the public ETS table `repos`. Shared with the
%%% `repo_lifecycle_to_repos` projection via `evoq_read_model_ets`
%%% named-table support.
%%%
%%% Keys: repo_id (binary). Values: map with
%%% realm/name/owner_did/description/default_branch/tags/visibility/
%%% status/initiated_at/revised_at/archived_at.
%%% @end
-module(project_repos_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([list/0, get/1, list_by_owner/1, list_by_realm/1, search_by_tag/1, search_by_tag/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TABLE, repos).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%====================================================================
%% Query API (reads directly from public ETS)
%%====================================================================

-spec list() -> {ok, [map()]}.
list() ->
    try
        {ok, [V || {_K, V} <- ets:tab2list(?TABLE)]}
    catch
        error:badarg -> {ok, []}
    end.

-spec get(binary()) -> {ok, map()} | {error, not_found}.
get(RepoId) when is_binary(RepoId) ->
    try
        case ets:lookup(?TABLE, RepoId) of
            [{_, Entry}] -> {ok, Entry};
            []           -> {error, not_found}
        end
    catch
        error:badarg -> {error, not_found}
    end.

-spec list_by_owner(binary()) -> {ok, [map()]}.
list_by_owner(OwnerDid) when is_binary(OwnerDid) ->
    {ok, All} = ?MODULE:list(),
    {ok, [E || #{owner_did := D} = E <- All, D =:= OwnerDid]}.

-spec list_by_realm(binary()) -> {ok, [map()]}.
list_by_realm(Realm) when is_binary(Realm) ->
    {ok, All} = ?MODULE:list(),
    {ok, [E || #{realm := R} = E <- All, R =:= Realm]}.

-spec search_by_tag(binary()) -> {ok, [map()]}.
search_by_tag(Tag) when is_binary(Tag) ->
    {ok, All} = ?MODULE:list(),
    {ok, [E || #{tags := Ts} = E <- All, lists:member(Tag, Ts)]}.

-spec search_by_tag(binary(), binary()) -> {ok, [map()]}.
search_by_tag(Tag, Realm) when is_binary(Tag), is_binary(Realm) ->
    {ok, ByRealm} = list_by_realm(Realm),
    {ok, [E || #{tags := Ts} = E <- ByRealm, lists:member(Tag, Ts)]}.

%%====================================================================
%% gen_server callbacks — table lifecycle
%%====================================================================

init([]) ->
    case ets:info(?TABLE) of
        undefined ->
            ets:new(?TABLE, [named_table, public, set, {read_concurrency, true}]);
        _ ->
            ok
    end,
    {ok, #{}}.

handle_call(_Msg, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State)        -> {noreply, State}.
handle_info(_Msg, State)        -> {noreply, State}.
terminate(_Reason, _State)      -> ok.
