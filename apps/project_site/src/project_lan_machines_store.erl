%%% @doc Query facade for the lan_machines ETS read model.
%%%
%%% Keyed by MAC. Each row aggregates observations from every
%%% BEAM-node observer that has spotted this MAC. Per-observer
%%% dismissals hide the machine from that observer's UI view.
%%%
%%% Row shape:
%%%   #{mac         := binary(),
%%%     observations := #{Observer => #{ip, hostname, interface,
%%%                                     ssh, hecate, spotted_at}},
%%%     dismissed_by := #{Observer => DismissedAt}}
%%%
%%% The table is created here and shared with the projection via
%%% evoq_read_model_ets named-table support.
%%% @end
-module(project_lan_machines_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([get/1, list_all/0, list_visible/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TABLE, lan_machines).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%====================================================================
%% Query API (reads directly from public ETS)
%%====================================================================

-spec get(binary()) -> {ok, map()} | {error, not_found}.
get(MAC) ->
    case ets:lookup(?TABLE, MAC) of
        [{_, Entry}] -> {ok, Entry};
        [] -> {error, not_found}
    end.

-spec list_all() -> {ok, [map()]}.
list_all() ->
    Rows = [Entry || {_MAC, Entry} <- ets:tab2list(?TABLE)],
    {ok, Rows}.

%% @doc List machines not dismissed by Observer.
-spec list_visible(binary()) -> {ok, [map()]}.
list_visible(Observer) ->
    {ok, All} = list_all(),
    Visible = [Row || Row <- All,
                      not maps:is_key(Observer, maps:get(dismissed_by, Row, #{}))],
    {ok, Visible}.

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
