%%% @doc ETS-backed read model for unified mesh activity.
%%%
%%% Single named table `mesh_activity', ordered_set keyed by `{TsMs, Seq}'
%%% so reads can return everything since a given timestamp in chronological
%%% order. `Seq' (a monotonic positive integer) tie-breaks within the same
%%% millisecond. Each row holds an activity map:
%%%
%%%   #{fact_id   => binary(),
%%%     kind      => <<"mesh_fact_published">> | <<"mesh_artifact_shared">>,
%%%     ts_ms     => integer(),
%%%     payload   => map()}
%%%
%%% The two projections (`mesh_fact_published_v1_to_mesh_activity' and
%%% `mesh_artifact_shared_v1_to_mesh_activity') call `record/1' to insert.
%%% @end
-module(project_mesh_activity_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([record/1, since/1, since/2, all/0]).
-export([init/1, handle_call/3, handle_cast/2]).

-define(TABLE, mesh_activity).
-define(DEFAULT_LIMIT, 200).
-define(MAX_LIMIT, 2000).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    ets:new(?TABLE, [public, named_table, ordered_set, {read_concurrency, true},
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
%% Internal
%%====================================================================

materialize('$end_of_table') -> [];
materialize({Rows, _Cont}) -> Rows.
