%%% @doc ETS-backed read model facade for the briefcase domain.
%%%
%%% Two named ETS tables:
%%%   - briefcase_folder_tree (keyed by folder_id)
%%%   - briefcase_file_index  (keyed by file_id)
%%%
%%% Creates the tables on start_link, then projections join them
%%% via evoq_read_model_ets shared named table support.
%%% @end
-module(project_briefcase_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Folder queries
-export([list_folders/0, get_folder/1]).

%% File queries
-export([list_files/1, get_file/1, count_files_in_folder/1]).

%% Write API (called by projections only)
-export([put_folder/2, delete_folder/1, put_file/2, delete_file/1]).

-define(FOLDER_TABLE, briefcase_folder_tree).
-define(FILE_TABLE, briefcase_file_index).

%% Archived status bit
-define(ARCHIVED, 8).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%====================================================================
%% Folder Query API (reads directly from public ETS)
%%====================================================================

%% @doc List all folders in the tree.
-spec list_folders() -> [map()].
list_folders() ->
    [F || {_K, F} <- ets:tab2list(?FOLDER_TABLE)].

%% @doc Get a single folder by ID.
-spec get_folder(binary()) -> {ok, map()} | {error, not_found}.
get_folder(FolderId) ->
    case ets:lookup(?FOLDER_TABLE, FolderId) of
        [{_, Folder}] -> {ok, Folder};
        [] -> {error, not_found}
    end.

%%====================================================================
%% File Query API (reads directly from public ETS)
%%====================================================================

%% @doc List files matching filter criteria.
%%
%% Supported filter keys:
%%   folder_id  - match exact folder (undefined = root, <<"all">> = no filter)
%%   starred    - true = only starred files
%%   search     - substring match on name (case-insensitive)
%%   file_type  - match exact file type
%%
%% Archived files (status band 8 =/= 0) are always excluded.
-spec list_files(map()) -> [map()].
list_files(Filters) ->
    All = ets:tab2list(?FILE_TABLE),
    [F || {_K, #{status := S} = F} <- All,
          S band ?ARCHIVED =:= 0,
          matches_filters(F, Filters)].

%% @doc Get a single file by ID.
-spec get_file(binary()) -> {ok, map()} | {error, not_found}.
get_file(FileId) ->
    case ets:lookup(?FILE_TABLE, FileId) of
        [{_, File}] -> {ok, File};
        [] -> {error, not_found}
    end.

%% @doc Count files in a specific folder.
-spec count_files_in_folder(binary() | undefined) -> integer().
count_files_in_folder(FolderId) ->
    All = ets:tab2list(?FILE_TABLE),
    length([F || {_K, #{folder_id := FId, status := S} = F} <- All,
                 FId =:= FolderId,
                 S band ?ARCHIVED =:= 0]).

%%====================================================================
%% Write API (called by projections only)
%%====================================================================

-spec put_folder(binary(), map()) -> ok.
put_folder(FolderId, Folder) ->
    true = ets:insert(?FOLDER_TABLE, {FolderId, Folder}),
    ok.

-spec delete_folder(binary()) -> ok.
delete_folder(FolderId) ->
    true = ets:delete(?FOLDER_TABLE, FolderId),
    ok.

-spec put_file(binary(), map()) -> ok.
put_file(FileId, File) ->
    true = ets:insert(?FILE_TABLE, {FileId, File}),
    ok.

-spec delete_file(binary()) -> ok.
delete_file(FileId) ->
    true = ets:delete(?FILE_TABLE, FileId),
    ok.

%%====================================================================
%% gen_server (owns the ETS tables)
%%====================================================================

init([]) ->
    ?FOLDER_TABLE = ets:new(?FOLDER_TABLE, [set, public, named_table, {read_concurrency, true}]),
    ?FILE_TABLE = ets:new(?FILE_TABLE, [set, public, named_table, {read_concurrency, true}]),
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%====================================================================
%% Internal
%%====================================================================

matches_filters(File, Filters) ->
    matches_folder_id(File, Filters) andalso
    matches_starred(File, Filters) andalso
    matches_search(File, Filters) andalso
    matches_file_type(File, Filters).

matches_folder_id(_File, #{folder_id := <<"all">>}) ->
    true;
matches_folder_id(#{folder_id := FId}, #{folder_id := FilterFId}) ->
    FId =:= FilterFId;
matches_folder_id(_File, _Filters) ->
    true.

matches_starred(#{starred := true}, #{starred := true}) ->
    true;
matches_starred(_File, #{starred := true}) ->
    false;
matches_starred(_File, _Filters) ->
    true.

matches_search(#{name := Name}, #{search := Search}) when is_binary(Search), Search =/= <<>> ->
    LowerName = string:lowercase(binary_to_list(Name)),
    LowerSearch = string:lowercase(binary_to_list(Search)),
    string:find(LowerName, LowerSearch) =/= nomatch;
matches_search(_File, _Filters) ->
    true.

matches_file_type(#{file_type := FT}, #{file_type := FilterFT}) when is_binary(FilterFT), FilterFT =/= <<>> ->
    FT =:= FilterFT;
matches_file_type(_File, _Filters) ->
    true.
