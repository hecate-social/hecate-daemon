%%% @doc Gen_server managing one live snake duel.
%%%
%%% Owns the game timer, ticks the engine, broadcasts state via pg group.
%%% SSE stream handlers join the duel's pg group to receive state updates.
%%%
%%% Duel lifecycle:
%%%   1. start_link(Config) -- creates game, registers in pg
%%%   2. Countdown phase (3, 2, 1, GO) at 800ms intervals
%%%   3. Game ticks at configured tickMs intervals
%%%   4. On collision/game-over: broadcasts final state, stops
%%% @end
-module(duel_proc).
-behaviour(gen_server).

-include("snake_duel.hrl").

-export([start_link/1, get_state/1, game_to_map/2]).
-export([init/1, handle_info/2, handle_call/3, handle_cast/2, terminate/2]).

-define(COUNTDOWN_MS, 800).

-record(duel, {
    match_id   :: binary(),
    game       :: game_state(),
    tick_ms    :: non_neg_integer(),
    af1        :: non_neg_integer(),
    af2        :: non_neg_integer(),
    started_at :: non_neg_integer(),
    timer      :: reference() | undefined
}).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------

-spec start_link(map()) -> {ok, pid()} | {error, term()}.
start_link(Config) ->
    gen_server:start_link(?MODULE, Config, []).

-spec get_state(pid()) -> {ok, map()}.
get_state(Pid) ->
    gen_server:call(Pid, get_state).

%%--------------------------------------------------------------------
%% Callbacks
%%--------------------------------------------------------------------

init(#{match_id := MatchId} = Config) ->
    AF1 = maps:get(af1, Config, 50),
    AF2 = maps:get(af2, Config, 50),
    TickMs = maps:get(tick_ms, Config, ?DEFAULT_TICK_MS),

    Game0 = snake_duel_engine:create_game(AF1, AF2),
    Game1 = Game0#game_state{status = countdown},

    %% Register in pg group for this duel
    ensure_pg(),
    pg:join(pg, duel_group(MatchId), self()),

    %% Also register by match_id for lookup
    persistent_term:put({snake_duel, MatchId}, self()),

    %% Start countdown
    Timer = erlang:send_after(?COUNTDOWN_MS, self(), countdown_tick),

    StartedAt = erlang:system_time(millisecond),

    logger:info("[snake_duel] Duel ~s started (AF1=~p, AF2=~p, tick=~pms)",
                [MatchId, AF1, AF2, TickMs]),

    %% Broadcast initial state
    broadcast(MatchId, Game1),

    {ok, #duel{match_id = MatchId, game = Game1, tick_ms = TickMs,
               af1 = AF1, af2 = AF2, started_at = StartedAt, timer = Timer}}.

handle_call(get_state, _From, #duel{game = Game, match_id = MatchId} = State) ->
    {reply, {ok, game_to_map(MatchId, Game)}, State};
handle_call(_Msg, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Countdown tick
handle_info(countdown_tick, #duel{game = #game_state{countdown = 1} = Game,
                                   match_id = MatchId, tick_ms = TickMs} = State) ->
    %% Final countdown -- transition to running
    Game1 = Game#game_state{countdown = 0, status = running},
    broadcast(MatchId, Game1),
    Timer = erlang:send_after(TickMs, self(), game_tick),
    {noreply, State#duel{game = Game1, timer = Timer}};

handle_info(countdown_tick, #duel{game = #game_state{countdown = N} = Game,
                                   match_id = MatchId} = State) when N > 1 ->
    Game1 = Game#game_state{countdown = N - 1},
    broadcast(MatchId, Game1),
    Timer = erlang:send_after(?COUNTDOWN_MS, self(), countdown_tick),
    {noreply, State#duel{game = Game1, timer = Timer}};

%% Game tick
handle_info(game_tick, #duel{game = Game0, match_id = MatchId,
                              tick_ms = TickMs} = State) ->
    Game1 = snake_duel_engine:tick_game(Game0),
    broadcast(MatchId, Game1),
    case Game1#game_state.status of
        finished ->
            logger:info("[snake_duel] Duel ~s finished, winner=~p",
                        [MatchId, Game1#game_state.winner]),
            record_result(State#duel{game = Game1}),
            {stop, normal, State#duel{game = Game1, timer = undefined}};
        _ ->
            Timer = erlang:send_after(TickMs, self(), game_tick),
            {noreply, State#duel{game = Game1, timer = Timer}}
    end;

handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, #duel{match_id = MatchId, timer = Timer}) ->
    case Timer of
        undefined -> ok;
        Ref -> erlang:cancel_timer(Ref)
    end,
    persistent_term:erase({snake_duel, MatchId}),
    ok.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

record_result(#duel{match_id = MatchId, game = Game,
                    af1 = AF1, af2 = AF2, tick_ms = TickMs,
                    started_at = StartedAt}) ->
    try
        query_snake_duel_store:record_match(#{
            match_id => MatchId,
            winner => Game#game_state.winner,
            af1 => AF1,
            af2 => AF2,
            tick_ms => TickMs,
            score1 => (Game#game_state.snake1)#snake.score,
            score2 => (Game#game_state.snake2)#snake.score,
            ticks => Game#game_state.tick,
            started_at => StartedAt
        })
    catch
        _:Err ->
            logger:warning("[snake_duel] Failed to record duel ~s: ~p", [MatchId, Err])
    end.

duel_group(MatchId) ->
    {snake_duel, MatchId}.

ensure_pg() ->
    case pg:start(pg) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.

broadcast(MatchId, Game) ->
    Msg = {snake_duel_state, game_to_map(MatchId, Game)},
    Members = pg:get_members(pg, duel_group(MatchId)),
    [Pid ! Msg || Pid <- Members, Pid =/= self()].

%%--------------------------------------------------------------------
%% Serialization -- game state to JSON-friendly map
%%--------------------------------------------------------------------

game_to_map(MatchId, #game_state{} = G) ->
    #{
        match_id => MatchId,
        snake1 => snake_to_map(G#game_state.snake1),
        snake2 => snake_to_map(G#game_state.snake2),
        food => point_to_list(G#game_state.food),
        poison_apples => [poison_to_map(P) || P <- G#game_state.poison_apples],
        walls => [wall_to_map(W) || W <- G#game_state.walls],
        status => G#game_state.status,
        winner => G#game_state.winner,
        tick => G#game_state.tick,
        countdown => G#game_state.countdown
    }.

snake_to_map(#snake{} = S) ->
    #{
        body => [point_to_list(P) || P <- S#snake.body],
        direction => S#snake.direction,
        score => S#snake.score,
        asshole_factor => S#snake.asshole_factor,
        events => [event_to_map(E) || E <- S#snake.events]
    }.

event_to_map(#game_event{} = E) ->
    #{type => E#game_event.type, value => E#game_event.value, tick => E#game_event.tick}.

poison_to_map(#poison_apple{} = P) ->
    #{pos => point_to_list(P#poison_apple.pos), owner => P#poison_apple.owner}.

wall_to_map(#wall_tile{} = W) ->
    #{pos => point_to_list(W#wall_tile.pos),
      owner => W#wall_tile.owner,
      ttl => W#wall_tile.ttl}.

point_to_list({X, Y}) -> [X, Y].
