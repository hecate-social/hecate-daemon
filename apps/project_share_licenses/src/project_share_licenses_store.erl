%%% @doc ETS owner + query facade for share-license read models.
%%%
%%% Tables:
%%%
%%%   `my_issued_realm_scoped_active_licenses` (issuer-side rewrap index)
%%%     Key:   `license_id`
%%%     Value: `#{license_id, realm, k_realm_version, wrap_strategy,
%%%               issuer_did, grantee, origin_cek_sealed, issued_at}`
%%%     Only realm-scope licenses this daemon issued are tracked — the
%%%     only ones that need rewrapping on K_realm rotation. DID-scope
%%%     licenses don't rotate; filtered out at insert.
%%%
%%%     The `origin_cek_sealed` field is kept in the row so the rewrap
%%%     PM can decrypt + re-wrap without loading the aggregate — matters
%%%     when an issuer has thousands of licenses.
%%%
%%%   `my_accepted_share_licenses` (recipient-side open-path index)
%%%     Key:   `file_id`
%%%     Value: `#{file_id, license_id, realm, k_realm_version,
%%%               wrap_strategy, wrapped_cek, accepted_cek_sealed,
%%%               issuer_did, status, expires_at, ...}`
%%%     One entry per file the recipient has accepted a license for.
%%%     Phase F open-path queries this by file_id + runs the staleness
%%%     guard against the entry's status/expires_at/realm.
%%% @end
-module(project_share_licenses_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([get/1,
         list_active_for_realm_version/2,
         list_all/0,
         get_accepted_by_file_id/1,
         list_accepted/0,
         get_issued_file/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TABLE, my_issued_realm_scoped_active_licenses).
-define(ACCEPTED_TABLE, my_accepted_share_licenses).
-define(FILES_TABLE, my_issued_files).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%====================================================================
%% Query API
%%====================================================================

-spec get(binary()) -> {ok, map()} | {error, not_found}.
get(LicenseId) ->
    case ets:whereis(?TABLE) of
        undefined -> {error, not_found};
        _ ->
            case ets:lookup(?TABLE, LicenseId) of
                [{_, Entry}] -> {ok, Entry};
                []           -> {error, not_found}
            end
    end.

%% @doc List all active realm-scope licenses issued by this daemon for
%% a given (realm, k_realm_version) pair. Used by the rewrap PM on
%% rotation to enumerate the rewrap work set for the old version.
-spec list_active_for_realm_version(binary(), pos_integer()) -> {ok, [map()]}.
list_active_for_realm_version(Realm, Version)
  when is_binary(Realm), is_integer(Version) ->
    case ets:whereis(?TABLE) of
        undefined -> {ok, []};
        _ ->
            All = ets:tab2list(?TABLE),
            Matching = [E ||
                {_Key, #{realm := R, k_realm_version := V} = E} <- All,
                R =:= Realm,
                V =:= Version],
            {ok, Matching}
    end.

-spec list_all() -> {ok, [map()]}.
list_all() ->
    case ets:whereis(?TABLE) of
        undefined -> {ok, []};
        _ -> {ok, [E || {_, E} <- ets:tab2list(?TABLE)]}
    end.

%% @doc Recipient-side lookup: fetch the accepted share-license row
%% for a given file_id. Used by the Phase F open-path guard.
-spec get_accepted_by_file_id(binary()) -> {ok, map()} | {error, not_found}.
get_accepted_by_file_id(FileId) when is_binary(FileId) ->
    case ets:whereis(?ACCEPTED_TABLE) of
        undefined -> {error, not_found};
        _ ->
            case ets:lookup(?ACCEPTED_TABLE, FileId) of
                [{_, Entry}] -> {ok, Entry};
                []           -> {error, not_found}
            end
    end.

-spec list_accepted() -> {ok, [map()]}.
list_accepted() ->
    case ets:whereis(?ACCEPTED_TABLE) of
        undefined -> {ok, []};
        _ -> {ok, [E || {_, E} <- ets:tab2list(?ACCEPTED_TABLE)]}
    end.

%% @doc Issuer-side per-file index entry. Returns the sealed CEK +
%% realm + issuer for a file this daemon has shared. Used by the
%% encrypt-on-serve path.
-spec get_issued_file(binary()) -> {ok, map()} | {error, not_found}.
get_issued_file(FileId) when is_binary(FileId) ->
    case ets:whereis(?FILES_TABLE) of
        undefined -> {error, not_found};
        _ ->
            case ets:lookup(?FILES_TABLE, FileId) of
                [{_, Entry}] -> {ok, Entry};
                []           -> {error, not_found}
            end
    end.

%%====================================================================
%% gen_server (ETS owner)
%%====================================================================

init([]) ->
    ensure_table(?TABLE),
    ensure_table(?ACCEPTED_TABLE),
    ensure_table(?FILES_TABLE),
    {ok, #{}}.

ensure_table(Name) ->
    case ets:info(Name) of
        undefined ->
            Name = ets:new(Name, [set, public, named_table,
                                  {read_concurrency, true},
                                  {write_concurrency, true}]);
        _ ->
            ok
    end.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.
