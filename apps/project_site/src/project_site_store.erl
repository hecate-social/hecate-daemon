%%% @doc Query facade for the site ETS read model.
%%%
%%% Singleton row keyed by atom 'site'.
%%% The table is created here and shared with the merged projection
%%% via evoq_read_model_ets named table support.
%%% @end
-module(project_site_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([get/0, get_nodes/0, get_realm/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TABLE, site).
-define(KEY, site).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%====================================================================
%% Query API (reads directly from public ETS)
%%====================================================================

-spec get() -> {ok, map()} | {error, not_found}.
get() ->
    case ets:lookup(?TABLE, ?KEY) of
        [{_, Entry}] -> {ok, Entry};
        [] -> {error, not_found}
    end.

-spec get_nodes() -> {ok, map()}.
get_nodes() ->
    case ?MODULE:get() of
        {ok, #{nodes := Nodes}} -> {ok, Nodes};
        _ -> {ok, #{}}
    end.

-spec get_realm() -> {ok, map()} | {error, not_joined}.
get_realm() ->
    case ?MODULE:get() of
        {ok, #{realm := Realm, realm_url := RealmUrl,
               oauth_account := OauthAccount, oauth_provider := OauthProvider}}
          when Realm =/= undefined ->
            {ok, #{realm => Realm,
                   realm_url => RealmUrl,
                   oauth_account => OauthAccount,
                   oauth_provider => OauthProvider}};
        _ -> {error, not_joined}
    end.

%%====================================================================
%% gen_server (owns the ETS table)
%%====================================================================

init([]) ->
    ?TABLE = ets:new(?TABLE, [set, public, named_table, {read_concurrency, true}]),
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.
