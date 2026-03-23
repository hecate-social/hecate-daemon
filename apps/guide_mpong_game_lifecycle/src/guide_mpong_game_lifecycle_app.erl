%%%-------------------------------------------------------------------
%%% @doc guide_mpong_game_lifecycle application behaviour.
%%%
%%% On boot: auto-registers a champion bot if one doesn't exist.
%%% @end
%%%-------------------------------------------------------------------
-module(guide_mpong_game_lifecycle_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    {ok, Pid} = guide_mpong_game_lifecycle_sup:start_link(),
    %% Auto-register champion (async, non-blocking)
    spawn(fun() ->
        %% Wait for mpong_store to be ready
        timer:sleep(3000),
        ensure_champion()
    end),
    {ok, Pid}.

stop(_State) ->
    ok.

ensure_champion() ->
    NodeId = atom_to_binary(node()),
    %% Check if champion already registered (via ETS projection)
    case ets:info(mpong_champions) of
        undefined ->
            %% Projection table not yet created, retry later
            timer:sleep(2000),
            ensure_champion();
        _ ->
            case ets:lookup(mpong_champions, NodeId) of
                [{_, _Champion}] ->
                    logger:info("[mpong] Champion already registered for ~s", [NodeId]);
                [] ->
                    logger:info("[mpong] Registering champion for ~s", [NodeId]),
                    case maybe_register_champion:dispatch() of
                        {ok, _V, _Events} ->
                            #{name := Name} = maybe_register_champion:generate_champion(),
                            logger:info("[mpong] Champion registered: ~s", [Name]);
                        {error, Reason} ->
                            logger:warning("[mpong] Failed to register champion: ~p", [Reason])
                    end
            end
    end.
