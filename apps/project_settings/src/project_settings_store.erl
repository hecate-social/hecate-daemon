%%% @doc Query facade for the settings ETS read model.
%%%
%%% Singleton row keyed by atom 'settings'.
%%% The table is created here and shared with the merged projection
%%% via evoq_read_model_ets named table support.
%%% @end
-module(project_settings_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([get/0, get_identity/0, get_preferences/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TABLE, settings).
-define(KEY, settings).

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

-spec get_identity() -> {ok, map()} | {error, not_found}.
get_identity() ->
    case ?MODULE:get() of
        {ok, #{hecate_user_id := HecateUserId, linux_user := LinuxUser,
               hostname := Hostname}} ->
            {ok, #{hecate_user_id => HecateUserId,
                   linux_user => LinuxUser,
                   hostname => Hostname}};
        Other -> Other
    end.

-spec get_preferences() -> {ok, map()}.
get_preferences() ->
    case ?MODULE:get() of
        {ok, #{preferences := Prefs}} -> {ok, Prefs};
        _ -> {ok, #{}}
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
