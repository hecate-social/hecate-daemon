%%%-------------------------------------------------------------------
%%% @doc Auto-hosts a bot-vs-bot mpong match on a timer for the public
%%% demo at macula.io/demo/mpong.
%%%
%%% When enabled (`{hecate, mpong_auto_host}' = true), a fresh quick-
%%% start match is hosted whenever the game-engine supervisor is idle.
%%% Each match runs to completion (engine dies), then the next tick
%%% hosts a new one. This guarantees the realm's spectator view is
%%% never empty.
%%%
%%% Disabled by default — only beam-cluster daemons designated for
%%% the public demo should set the env to `true'.
%%% @end
%%%-------------------------------------------------------------------
-module(auto_host_demo_loop).
-behaviour(gen_server).

-include_lib("evoq/include/evoq.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

%% Default tick spacing — overridable via `{hecate, mpong_auto_host_interval_ms}'.
-define(DEFAULT_INTERVAL_MS, 90_000).

%% Re-announce heartbeat for the currently-hosted game. Single-shot
%% advertise publishes lose to bloom-fan propagation timing; spamming
%% them every few seconds while the engine runs gives the realm a
%% reliable lobby tile. Overridable via `{hecate, mpong_auto_host_announce_ms}'.
-define(DEFAULT_ANNOUNCE_MS, 10_000).

%% Quiet pause before the first match so the daemon's mesh + identity
%% subsystems can settle. Overridable via `{hecate, mpong_auto_host_boot_delay_ms}'.
-define(DEFAULT_BOOT_DELAY_MS, 15_000).

%% Bots per match. Two = classic pong layout. Overridable via
%% `{hecate, mpong_auto_host_bot_count}'.
-define(DEFAULT_BOT_COUNT, 2).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    BootDelay = env_int(mpong_auto_host_boot_delay_ms, ?DEFAULT_BOOT_DELAY_MS),
    logger:info("[auto_host_demo_loop] enabled — first tick in ~pms", [BootDelay]),
    erlang:send_after(BootDelay, self(), tick),
    erlang:send_after(BootDelay + ?DEFAULT_ANNOUNCE_MS, self(), reannounce),
    {ok, #{current => undefined}}.

handle_call(_Req, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(tick, State) ->
    State1 = maybe_host(State),
    erlang:send_after(env_int(mpong_auto_host_interval_ms, ?DEFAULT_INTERVAL_MS),
                      self(), tick),
    {noreply, State1};
handle_info(reannounce, State) ->
    maybe_reannounce(State),
    erlang:send_after(env_int(mpong_auto_host_announce_ms, ?DEFAULT_ANNOUNCE_MS),
                      self(), reannounce),
    {noreply, State};
handle_info(_Msg, State) ->
    {noreply, State}.

%%====================================================================
%% Internal
%%====================================================================

maybe_host(State) ->
    case engines_active() of
        N when N >= 1 ->
            logger:debug("[auto_host_demo_loop] skipping — ~p engine(s) active", [N]),
            State;
        _ ->
            host_one_match(State)
    end.

%% Heartbeat re-publish of the current game's advertise fact. Without
%% this, the realm-side spectator misses single-shot publishes that
%% lose to bloom-fan propagation timing. Cheap, idempotent — the
%% realm's Mpong sink keys by game_id and only fans state diffs.
maybe_reannounce(#{current := undefined}) ->
    ok;
maybe_reannounce(#{current := #{game_id := GameId} = Current}) ->
    case engines_active() of
        N when N >= 1 ->
            advertise_game:announce(#{
                game_id      => GameId,
                host_node_id => maps:get(host_node_id, Current),
                max_players  => maps:get(max_players, Current)
            }),
            ok;
        _ ->
            ok
    end.

engines_active() ->
    try
        Counts = supervisor:count_children(run_game_engine_sup),
        proplists:get_value(active, Counts, 0)
    catch
        _:_ -> 0
    end.

host_one_match(State) ->
    GameId = generate_game_id(),
    HostNodeId = atom_to_binary(node()),
    BotCount = env_int(mpong_auto_host_bot_count, ?DEFAULT_BOT_COUNT),
    Cmd = host_game_v1:new(GameId, HostNodeId, BotCount),
    case maybe_host_game:dispatch(Cmd) of
        {ok, _V, _Events} ->
            %% Announce the game to the mesh — host_game's event store
            %% emits `game_hosted_v1' locally but no emitter subscribes
            %% to it, so without this explicit call no remote spectator
            %% (e.g. macula.io/demo/mpong) ever sees a lobby tile.
            %% `mpong_lobby_server' makes the same call on its happy
            %% path; the auto-host loop bypasses that server. The
            %% `reannounce' heartbeat re-publishes this every 10s
            %% while the engine runs.
            Current = #{game_id      => GameId,
                        host_node_id => HostNodeId,
                        max_players  => BotCount},
            advertise_game:announce(Current),
            quick_start(GameId, HostNodeId, BotCount),
            logger:info("[auto_host_demo_loop] hosted ~s (~p bots)",
                        [GameId, BotCount]),
            State#{current := Current};
        {error, Reason} ->
            logger:warning("[auto_host_demo_loop] dispatch failed: ~p", [Reason]),
            State
    end.

%% Mirrors host_mpong_game_api:quick_start/3. Kept in sync manually;
%% if either drifts, both should be updated.
quick_start(GameId, HostNodeId, BotCount) ->
    BotNames = [bot_name(I) || I <- lists:seq(1, BotCount)],
    lists:foldl(fun(BotName, WallIdx) ->
        dispatch_join(GameId, BotName, WallIdx),
        WallIdx + 1
    end, 0, BotNames),
    timer:sleep(100),
    dispatch_start(GameId, HostNodeId),
    timer:sleep(100),
    PlayersMap = maps:from_list([
        {BotName, #{wall_index => I}}
        || {I, BotName} <- lists:enumerate(0, BotNames)
    ]),
    run_game_engine_sup:start_engine(#{
        game_id => GameId,
        players => PlayersMap
    }).

dispatch_join(GameId, PlayerNodeId, _WallIndex) ->
    ChampionName = case binary:split(PlayerNodeId, <<"@">>) of
        [Name, _] -> Name;
        _ -> PlayerNodeId
    end,
    StreamId = mpong_game_aggregate:stream_id(GameId),
    EvoqCmd = #evoq_command{
        command_type = join_game,
        aggregate_type = mpong_game_aggregate,
        aggregate_id = StreamId,
        payload = #{
            command_type => join_game,
            game_id => GameId,
            player_node_id => PlayerNodeId,
            champion_name => ChampionName,
            transport => <<"local">>
        },
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => mpong_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

dispatch_start(GameId, HostNodeId) ->
    StreamId = mpong_game_aggregate:stream_id(GameId),
    EvoqCmd = #evoq_command{
        command_type = start_game,
        aggregate_type = mpong_game_aggregate,
        aggregate_id = StreamId,
        payload = #{
            command_type => start_game,
            game_id => GameId,
            host_node_id => HostNodeId
        },
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => mpong_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

bot_name(N) ->
    <<"bot_", (integer_to_binary(N))/binary, "@", (atom_to_binary(node()))/binary>>.

generate_game_id() ->
    binary:encode_hex(crypto:strong_rand_bytes(8), lowercase).

env_int(Key, Default) ->
    case application:get_env(hecate, Key, Default) of
        N when is_integer(N), N > 0 -> N;
        _ -> Default
    end.
