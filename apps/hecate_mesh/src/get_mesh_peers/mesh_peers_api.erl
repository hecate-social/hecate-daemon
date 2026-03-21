%%% @doc GET /api/mesh/peers — List known/connected mesh peers.
%%%
%%% Returns peers from the macula connection pool.
%%% @end
-module(mesh_peers_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mesh/peers", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    {ok, Peers} = hecate_mesh:get_peers(),
    %% Also get our own status for context
    OwnStatus = case hecate_mesh:get_status() of
        {ok, S} -> S;
        _ -> #{connected => false}
    end,
    hecate_api_utils:json_ok(#{
        peers => Peers,
        peer_count => length(Peers),
        self => maps:with([node_id, identity, realm], OwnStatus),
        connected => maps:get(connected, OwnStatus, false)
    }, Req0).
