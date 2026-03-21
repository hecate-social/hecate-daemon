%%% @doc Mesh proof endpoint: GET/POST /api/mesh/proof
%%%
%%% GET  - Returns current proof results
%%% POST - Triggers a re-run of the proof ceremony (202 Accepted)
%%% @end
-module(mesh_proof_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mesh/proof", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle_get(Req0, State);
        <<"POST">> ->
            handle_post(Req0, State);
        _ ->
            Req = cowboy_req:reply(405, #{
                <<"content-type">> => <<"application/json">>
            }, <<"{\"ok\":false,\"error\":\"method_not_allowed\"}">>, Req0),
            {ok, Req, State}
    end.

handle_get(Req0, State) ->
    Response = try mesh_proof_coordinator:get_proof_results()
               catch _:_ ->
                   #{ok => false, error => <<"proof_coordinator_not_available">>}
               end,
    Body = json:encode(Response),
    Req = cowboy_req:reply(200, #{
        <<"content-type">> => <<"application/json">>
    }, Body, Req0),
    {ok, Req, State}.

handle_post(Req0, State) ->
    try mesh_proof_coordinator:rerun_probes()
    catch _:_ -> ok
    end,
    Body = json:encode(#{ok => true, status => <<"accepted">>}),
    Req = cowboy_req:reply(202, #{
        <<"content-type">> => <<"application/json">>
    }, Body, Req0),
    {ok, Req, State}.
