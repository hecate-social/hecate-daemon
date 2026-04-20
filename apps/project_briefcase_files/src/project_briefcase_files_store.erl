%%% @doc Query facade for the briefcase_files ETS read model.
%%%
%%% Owns the public ETS table `briefcase_files`. Shared with
%%% `briefcase_lifecycle_to_files` projection via `evoq_read_model_ets`
%%% named-table support.
%%%
%%% Keys: file_id (binary). Values: map with
%%% realm/path/mime_type/size/content_hash/author_did/uploaded_at/status.
%%% @end
-module(project_briefcase_files_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([list/0, get/1, list_by_realm/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TABLE, briefcase_files).

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
get(FileId) when is_binary(FileId) ->
    try
        case ets:lookup(?TABLE, FileId) of
            [{_, Entry}] -> {ok, Entry};
            []           -> {error, not_found}
        end
    catch
        error:badarg -> {error, not_found}
    end.

-spec list_by_realm(binary()) -> {ok, [map()]}.
list_by_realm(Realm) when is_binary(Realm) ->
    {ok, All} = ?MODULE:list(),
    {ok, [E || #{realm := R} = E <- All, R =:= Realm]}.

%%====================================================================
%% gen_server callbacks — table lifecycle
%%====================================================================

init([]) ->
    %% Create the public named table; projection writes via
    %% evoq_read_model_ets with matching name.
    case ets:info(?TABLE) of
        undefined ->
            ets:new(?TABLE, [named_table, public, set, {read_concurrency, true}]);
        _ ->
            ok
    end,
    {ok, #{}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State)        -> {noreply, State}.
handle_info(_Info, State)       -> {noreply, State}.
terminate(_Reason, _State)      -> ok.
