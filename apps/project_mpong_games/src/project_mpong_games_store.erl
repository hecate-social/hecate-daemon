%%%-------------------------------------------------------------------
%%% @doc ETS store facade for MPong games read model.
%%%
%%% Owns the `mpong_games` ETS table. Provides typed read functions
%%% for the QRY app.
%%% @end
%%%-------------------------------------------------------------------
-module(project_mpong_games_store).
-behaviour(gen_server).

-export([start_link/0]).
-export([get/1, list_active/0, list_all/0, put/2, delete/1]).
-export([put_engine_state/2, get_engine_state/1]).
-export([init/1, handle_call/3, handle_cast/2]).

-define(TABLE, mpong_games).

%%====================================================================
%% API
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec get(binary()) -> {ok, map()} | {error, not_found}.
get(GameId) ->
    case ets:lookup(?TABLE, GameId) of
        [{GameId, Game}] -> {ok, sanitize(Game)};
        [] -> {error, not_found}
    end.

-spec list_active() -> [map()].
list_active() ->
    ets:foldl(fun({_Id, #{status := Status} = Game}, Acc) ->
        case Status of
            <<"waiting">> -> [sanitize(Game) | Acc];
            <<"playing">> -> [sanitize(Game) | Acc];
            _ -> Acc
        end
    end, [], ?TABLE).

-spec list_all() -> [map()].
list_all() ->
    [sanitize(Game) || {_Id, Game} <- ets:tab2list(?TABLE)].

-spec put(binary(), map()) -> ok.
put(GameId, Game) ->
    ets:insert(?TABLE, {GameId, Game}),
    ok.

-spec delete(binary()) -> ok.
delete(GameId) ->
    ets:delete(?TABLE, GameId),
    ok.

%% Engine real-time state (written by engine every tick, read by poll endpoint)
-define(ENGINE_TABLE, mpong_engine_state).

-spec put_engine_state(binary(), map()) -> ok.
put_engine_state(GameId, State) ->
    ets:insert(?ENGINE_TABLE, {GameId, State}),
    ok.

-spec get_engine_state(binary()) -> {ok, map()} | {error, not_found}.
get_engine_state(GameId) ->
    case ets:lookup(?ENGINE_TABLE, GameId) of
        [{GameId, State}] -> {ok, State};
        [] -> {error, not_found}
    end.

%%====================================================================
%% gen_server
%%====================================================================

init([]) ->
    ?TABLE = ets:new(?TABLE, [set, public, named_table, {read_concurrency, true}]),
    ?ENGINE_TABLE = ets:new(?ENGINE_TABLE, [set, public, named_table, {read_concurrency, true}]),
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Replace undefined atoms with null for JSON serialization
sanitize(Map) when is_map(Map) ->
    maps:map(fun(_K, undefined) -> null;
                (_K, V) when is_map(V) -> sanitize(V);
                (_K, V) when is_list(V) -> [sanitize_val(E) || E <- V];
                (_K, V) -> V
             end, Map).

sanitize_val(V) when is_map(V) -> sanitize(V);
sanitize_val(undefined) -> null;
sanitize_val(V) -> V.
