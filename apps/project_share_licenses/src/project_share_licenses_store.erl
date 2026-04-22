%%% @doc ETS owner + query facade for the issuer-side rewrap index.
%%%
%%% Table: `my_issued_realm_scoped_active_licenses`
%%% Key:   `license_id`
%%% Value: `#{license_id, realm, k_realm_version, wrap_strategy,
%%%           issuer_did, grantee, origin_cek_sealed, issued_at}`
%%%
%%% Only realm-scope licenses this daemon issued are tracked (the only
%%% licenses that need rewrapping on K_realm rotation). DID-scope
%%% licenses are unaffected by realm key rotation and are filtered out
%%% on insert by the projection.
%%%
%%% The `origin_cek_sealed` field is kept in the ETS row so the rewrap
%%% PM can decrypt + re-wrap without a second aggregate load — critical
%%% for keeping rotation fast when an issuer has thousands of licenses.
%%% @end
-module(project_share_licenses_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([get/1,
         list_active_for_realm_version/2,
         list_all/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TABLE, my_issued_realm_scoped_active_licenses).

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

%%====================================================================
%% gen_server (ETS owner)
%%====================================================================

init([]) ->
    ?TABLE = ets:new(?TABLE, [set, public, named_table,
                              {read_concurrency, true},
                              {write_concurrency, true}]),
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.
