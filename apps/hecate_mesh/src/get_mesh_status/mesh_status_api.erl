%%% @doc Mesh status endpoint: GET /api/mesh/status
%%%
%%% Returns the current mesh connection status from hecate_mesh_client.
%%% @end
-module(mesh_status_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mesh/status", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_get(Req0, State);
        _ ->
            Req = cowboy_req:reply(405, #{
                <<"content-type">> => <<"application/json">>
            }, <<"{\"ok\":false,\"error\":\"method_not_allowed\"}">>, Req0),
            {ok, Req, State}
    end.

handle_get(Req0, State) ->
    Response = case hecate_mesh:get_status() of
        {ok, Status} ->
            Peers = case hecate_mesh:get_peers() of
                {ok, P} -> P;
                _ -> []
            end,
            {ok, #{current_relay := CurrentRelay}} = hecate_mesh:get_neighborhood(),
            maps:merge(#{ok => true, peers => Peers, peer_count => length(Peers),
                         current_relay => CurrentRelay}, Status);
        {error, Reason} ->
            #{ok => false, error => iolist_to_binary(io_lib:format("~p", [Reason]))}
    end,
    Body = json:encode(Response),
    Req = cowboy_req:reply(200, #{
        <<"content-type">> => <<"application/json">>
    }, Body, Req0),
    {ok, Req, State}.
