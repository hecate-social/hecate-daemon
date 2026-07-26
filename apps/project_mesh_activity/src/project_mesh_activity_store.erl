%%% @doc ETS-backed read model for unified mesh activity + subscriptions.
%%%
%%% Two named tables owned by this gen_server:
%%%
%%%  * `mesh_activity', ordered_set keyed by `{TsMs, Seq}' — every
%%%    outgoing publish / share / inbound receive, in chronological
%%%    order. Each row:
%%%      #{fact_id => binary(), kind => <<"mesh_fact_published">> |
%%%        <<"mesh_artifact_shared">> | <<"mesh_fact_received">>,
%%%        ts_ms => integer(), payload => map()}
%%%    The three projections write here via `record/1'.
%%%
%%%  * `mesh_subscriptions', set keyed by `Topic' — current
%%%    subscription roster, populated by
%%%    `mesh_subscriptions_lifecycle_to_subscription_list'. Each row:
%%%      #{topic => binary(), subscribed_at => integer(),
%%%        fact_id => binary()}
%%%    Removed entries are deleted (not tombstoned).
%%% @end
-module(project_mesh_activity_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([record/1, since/1, since/2, all/0]).
-export([record_subscription/1, drop_subscription/1, list_subscriptions/0]).
-export([init/1, handle_call/3, handle_cast/2]).

-define(TABLE, mesh_activity).
-define(SUBS_TABLE, mesh_subscriptions).
-define(DEFAULT_LIMIT, 200).
-define(MAX_LIMIT, 2000).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ets:new(?TABLE, [public, named_table, ordered_set, {read_concurrency, true},
                     {write_concurrency, true}]),
    ets:new(?SUBS_TABLE, [public, named_table, set, {read_concurrency, true},
                          {write_concurrency, true}]),
    {ok, #{}}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.

%%====================================================================
%% Write API (used by projections)
%%====================================================================

-spec record(map()) -> ok.
record(#{ts_ms := TsMs} = Entry) when is_integer(TsMs) ->
    Seq = erlang:unique_integer([monotonic, positive]),
    ets:insert(?TABLE, {{TsMs, Seq}, Entry}),
    ok.

%%====================================================================
%% Query API (used by query_mesh_activity)
%%====================================================================

-spec since(integer()) -> {ok, [map()]}.
since(SinceMs) ->
    since(SinceMs, ?DEFAULT_LIMIT).

-spec since(integer(), pos_integer()) -> {ok, [map()]}.
since(SinceMs, Limit) when is_integer(SinceMs), is_integer(Limit), Limit > 0 ->
    Capped = min(Limit, ?MAX_LIMIT),
    MS = [{{{'$1', '_'}, '$2'}, [{'>=', '$1', SinceMs}], ['$2']}],
    Rows = ets:select(?TABLE, MS, Capped),
    {ok, materialize(Rows)}.

-spec all() -> {ok, [map()]}.
all() ->
    Rows = ets:tab2list(?TABLE),
    Sorted = lists:keysort(1, Rows),
    {ok, [V || {_K, V} <- Sorted]}.

%%====================================================================
%% Subscription roster (mesh_subscriptions table)
%%====================================================================

-spec record_subscription(map()) -> ok.
record_subscription(#{topic := Topic} = Entry) when is_binary(Topic) ->
    ets:insert(?SUBS_TABLE, {Topic, Entry}),
    ok.

-spec drop_subscription(binary()) -> ok.
drop_subscription(Topic) when is_binary(Topic) ->
    ets:delete(?SUBS_TABLE, Topic),
    ok.

-spec list_subscriptions() -> {ok, [map()]}.
list_subscriptions() ->
    Rows = ets:tab2list(?SUBS_TABLE),
    Entries = [V || {_K, V} <- Rows],
    Sorted = lists:sort(fun(#{subscribed_at := A}, #{subscribed_at := B}) ->
                            A =< B
                        end, Entries),
    {ok, Sorted}.

%%====================================================================
%% Internal
%%====================================================================

materialize('$end_of_table') -> [];
materialize({Rows, _Cont}) -> Rows.
