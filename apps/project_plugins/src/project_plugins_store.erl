%%% @doc Query facade for the plugins ETS read model.
%%%
%%% Provides typed access to the shared plugins ETS table.
%%% The table is created here (first to start) and shared with
%%% projection desks via evoq_read_model_ets named table support.
%%% @end
-module(project_plugins_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([get/1, list_active/0, list_by_status/1, list_all/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TABLE, plugins).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%====================================================================
%% Query API (reads directly from public ETS — no gen_server call)
%%====================================================================

%% @doc Get a single plugin by ID.
-spec get(binary()) -> {ok, map()} | {error, not_found}.
get(PluginId) ->
    case ets:lookup(?TABLE, PluginId) of
        [{_, Plugin}] -> {ok, Plugin};
        [] -> {error, not_found}
    end.

%% @doc List all non-removed plugins (status & 2 = 0).
-spec list_active() -> {ok, [map()]}.
list_active() ->
    All = ets:tab2list(?TABLE),
    Active = [P || {_Key, #{status := S} = P} <- All, S band 2 =:= 0],
    {ok, Active}.

%% @doc List plugins matching a status bitmask (status & Mask =/= 0).
-spec list_by_status(non_neg_integer()) -> {ok, [map()]}.
list_by_status(Mask) ->
    All = ets:tab2list(?TABLE),
    Matched = [P || {_Key, #{status := S} = P} <- All, S band Mask =/= 0],
    {ok, Matched}.

%% @doc List all plugins (including removed).
-spec list_all() -> {ok, [map()]}.
list_all() ->
    All = ets:tab2list(?TABLE),
    {ok, [P || {_Key, P} <- All]}.

%%====================================================================
%% gen_server (owns the ETS table)
%%====================================================================

init([]) ->
    %% Create the named ETS table. Projections join it via evoq_read_model_ets.
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
