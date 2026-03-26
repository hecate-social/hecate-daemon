%%%-------------------------------------------------------------------
%%% @doc Merged projection: game lifecycle events -> mpong_games ETS table.
%%%
%%% Handles all 6 game lifecycle events in one projection for ordering
%%% guarantees within a single game's event stream.
%%% Uses evoq_projection behaviour — subscription is automatic.
%%% @end
%%%-------------------------------------------------------------------
-module(game_lifecycle_to_mpong_games).
-behaviour(evoq_projection).

-export([interested_in/0, init/1, project/4]).

-define(TABLE, mpong_games).

%%====================================================================
%% evoq_projection callbacks
%%====================================================================

interested_in() ->
    [<<"game_hosted_v1">>,
     <<"player_joined_v1">>,
     <<"player_left_v1">>,
     <<"game_started_v1">>,
     <<"player_eliminated_v1">>,
     <<"game_ended_v1">>].

init(_Config) ->
    %% Use the ETS table created by project_mpong_games_store.
    %% Create a read model handle for evoq checkpoint tracking.
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => mpong_games_projection}),
    {ok, #{}, RM}.

project(#{data := Data} = Event, _Metadata, State, RM) ->
    case get_event_type(Event) of
        <<"game_hosted_v1">>        -> do_project_hosted(Data, State, RM);
        <<"player_joined_v1">>      -> do_project_joined(Data, State, RM);
        <<"player_left_v1">>        -> do_project_left(Data, State, RM);
        <<"game_started_v1">>       -> do_project_started(Data, State, RM);
        <<"player_eliminated_v1">>  -> do_project_eliminated(Data, State, RM);
        <<"game_ended_v1">>         -> do_project_ended(Data, State, RM);
        _                           -> {ok, State, RM}
    end;
project(_Event, _Metadata, State, RM) ->
    {ok, State, RM}.

%%====================================================================
%% Internal: Projections
%%====================================================================

do_project_hosted(Data, State, RM) ->
    GameId = gf(game_id, Data),
    Game = #{
        game_id => GameId,
        host_node_id => gf(host_node_id, Data),
        players => [],
        max_players => gf(max_players, Data, 8),
        status => <<"waiting">>,
        hosted_at => gf(hosted_at, Data),
        started_at => undefined,
        ended_at => undefined,
        winner_node_id => undefined
    },
    project_mpong_games_store:put(GameId, Game),
    {ok, State, RM}.

do_project_joined(Data, State, RM) ->
    GameId = gf(game_id, Data),
    case project_mpong_games_store:get(GameId) of
        {ok, Game} ->
            Player = #{
                node_id => gf(player_node_id, Data),
                wall_index => gf(wall_index, Data),
                alive => true,
                joined_at => gf(joined_at, Data),
                champion_name => nullify(gf(champion_name, Data)),
                transport => nullify(gf(transport, Data)),
                country => nullify(gf(country, Data)),
                city => nullify(gf(city, Data)),
                rtt_ms => nullify(gf(rtt_ms, Data)),
                nat_type => nullify(gf(nat_type, Data))
            },
            Players = maps:get(players, Game, []),
            project_mpong_games_store:put(GameId, Game#{players => Players ++ [Player]});
        _ -> ok
    end,
    {ok, State, RM}.

do_project_left(Data, State, RM) ->
    GameId = gf(game_id, Data),
    NodeId = gf(player_node_id, Data),
    case project_mpong_games_store:get(GameId) of
        {ok, #{players := Players} = Game} ->
            Filtered = [P || #{node_id := NId} = P <- Players, NId =/= NodeId],
            project_mpong_games_store:put(GameId, Game#{players => Filtered});
        _ -> ok
    end,
    {ok, State, RM}.

do_project_started(Data, State, RM) ->
    GameId = gf(game_id, Data),
    case project_mpong_games_store:get(GameId) of
        {ok, Game} ->
            project_mpong_games_store:put(GameId, Game#{
                status => <<"playing">>,
                started_at => gf(started_at, Data)
            });
        _ -> ok
    end,
    {ok, State, RM}.

do_project_eliminated(Data, State, RM) ->
    GameId = gf(game_id, Data),
    NodeId = gf(player_node_id, Data),
    case project_mpong_games_store:get(GameId) of
        {ok, #{players := Players} = Game} ->
            Updated = lists:map(fun(#{node_id := NId} = P) ->
                case NId =:= NodeId of
                    true -> P#{alive => false};
                    false -> P
                end
            end, Players),
            project_mpong_games_store:put(GameId, Game#{players => Updated});
        _ -> ok
    end,
    {ok, State, RM}.

do_project_ended(Data, State, RM) ->
    GameId = gf(game_id, Data),
    case project_mpong_games_store:get(GameId) of
        {ok, Game} ->
            project_mpong_games_store:put(GameId, Game#{
                status => <<"ended">>,
                winner_node_id => gf(winner_node_id, Data),
                ended_at => gf(ended_at, Data)
            });
        _ -> ok
    end,
    {ok, State, RM}.

%%====================================================================
%% Internal helpers
%%====================================================================

get_event_type(#{event_type := T}) -> T;
get_event_type(_) -> undefined.

nullify(undefined) -> null;
nullify(V) -> V.

gf(Key, Data) ->
    gf(Key, Data, undefined).

gf(Key, Data, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key),
    case maps:find(Key, Data) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Data) of
                {ok, V} -> V;
                error -> Default
            end
    end.
