%%%-------------------------------------------------------------------
%%% @doc guide_mpong_game_lifecycle application behaviour.
%%%
%%% On boot: auto-registers a champion bot if one doesn't exist.
%%% @end
%%%-------------------------------------------------------------------
-module(guide_mpong_game_lifecycle_app).
-behaviour(application).

-export([start/2, stop/1]).

-define(ENSURE_CHAMPION_GAP_MS, 3000).
-define(ENSURE_CHAMPION_MAX_TRIES, 40).   %% ~2 min — well past the slowest cold boot

start(_StartType, _StartArgs) ->
    {ok, Pid} = guide_mpong_game_lifecycle_sup:start_link(),
    %% Auto-register champion (async, non-blocking)
    spawn(fun() -> ensure_champion(?ENSURE_CHAMPION_MAX_TRIES) end),
    {ok, Pid}.

stop(_State) ->
    ok.

%% Keep dispatching `register_champion' until the champion actually
%% lands in the `mpong_champions' projection table — NOT just once
%% after a fixed 3s sleep. mpong_store is store #12 of 15 and on a
%% cold disk it isn't ready for ~6s; a dispatch to a not-yet-ready
%% store returns {ok,_} but the event is never persisted (the
%% catch-up then reads 0 events), so the old single-shot version left
%% `mpong_champions' empty forever — and every /api/mpong/lobby/open
%% then 400s `no_champion_registered', which is why the UI's host
%% buttons (Mesh / LAN / Quick start) did nothing.
ensure_champion(0) ->
    logger:warning("[mpong] Gave up registering champion after ~b tries",
                   [?ENSURE_CHAMPION_MAX_TRIES]);
ensure_champion(Tries) ->
    NodeId = atom_to_binary(node()),
    case champion_in_table(NodeId) of
        true ->
            logger:info("[mpong] Champion registered for ~s", [NodeId]);
        false ->
            _ = (catch maybe_register_champion:dispatch()),
            timer:sleep(?ENSURE_CHAMPION_GAP_MS),
            case champion_in_table(NodeId) of
                true  -> logger:info("[mpong] Champion registered for ~s", [NodeId]);
                false -> ensure_champion(Tries - 1)
            end
    end.

champion_in_table(NodeId) ->
    case ets:info(mpong_champions) of
        undefined -> false;
        _         -> ets:lookup(mpong_champions, NodeId) =/= []
    end.
